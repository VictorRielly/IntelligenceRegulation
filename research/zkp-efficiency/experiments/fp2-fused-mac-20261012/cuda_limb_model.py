"""CPU emulation of the CUDA two-u64 multiplication/addition seam, no GPU run.

High/low multiplication uses 32-bit schoolbook pieces. Reduction stays exactly
the local source-derived gl_reduce/CPU reducer; modular reference is independent.
"""
from field_support import F
from accumulator import canonical, reduce128
MASK=(1<<64)-1
LOW32=(1<<32)-1

def mul128(a,b):
    if not 0<=a<=MASK or not 0<=b<=MASK: raise ValueError('u64 product inputs')
    a0,a1=a&LOW32,a>>32; b0,b1=b&LOW32,b>>32
    low=a0*b0; middle=(low>>32)+a0*b1+a1*b0
    lo=(low&LOW32)|((middle&LOW32)<<32)
    hi=a1*b1+(middle>>32)
    assert hi<=MASK
    return lo,hi

def plus128(a,b):
    lo=(a[0]+b[0])&MASK; carry=int(lo<a[0])
    hi=a[1]+b[1]+carry
    if hi>MASK: raise OverflowError('u128 carry')
    return lo,hi

def red(a): return reduce128(a[0]+(a[1]<<64))

def mac(acc,x,y):
    canonical(acc); canonical(x); canonical(y)
    bd=red(mul128(x.b,y.b))
    real=red(plus128(plus128(mul128(x.a,y.a),mul128(7,bd)),(acc.a,0)))
    ad=red(mul128(x.a,y.b))
    imag=red(plus128(plus128(mul128(x.b,y.a),(ad,0)),(acc.b,0)))
    return F(real,imag)
