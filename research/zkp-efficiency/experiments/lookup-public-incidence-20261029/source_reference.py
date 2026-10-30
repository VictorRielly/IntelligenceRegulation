"""Restricted source reader and independent cell reference; imports no candidate.

Inspects the pinned R13 emitter. Not an execution of native define/validation.
"""
from pathlib import Path
import re
HERE=Path(__file__).resolve().parent

def catalog(h24,dd,wrho,p,gate,text=None):
    text=text or (HERE/'native/accuracy_layout.rs').read_text()
    text=re.sub(r'//[^\n]*','',text)
    counts={}
    for group,count in re.findall(r'(?:x\.group\(Dom::\w+|self\.group\(dom),Limbs::(\w+),"[^"]+",(if h24 \{\d+\} else \{\d+\}|\d+|ls),',text):
        if count=='ls':n=(wrho+7)//8
        elif count.startswith('if'):n=int(re.findall(r'\{(\d+)\}',count)[0 if h24 else 1])
        else:n=int(count)
        counts[group]=n
    assert len(counts)==34,counts
    body=text.split('match dom {',1)[1].split('if v.iter()',1)[0]
    def read(block,d):
        out=[]
        calls=re.findall(r'bytes\(Limbs::(\w+),(None|Some\([^)]*\))\)\?;',block)
        for g,b in calls:
            out.extend((d,f'{g}:{k}',1,0) for k in range(counts[g]))
            if b!='None':
                arg=b[5:-1]
                if arg=='wrho_s':bits=wrho
                elif arg=='gate_shift':bits=gate
                elif arg=='SH_ROPE':bits=7
                elif arg=='p.f_p+1':bits=13
                else:bits=p[arg.removeprefix('p.')]
                if not 8*(counts[g]-1)<bits<=8*counts[g]:raise ValueError('window')
                out.append((d,f'{g}:{counts[g]-1}',2**(8*counts[g]-bits),0))
        return out
    out={'L':[('L','A_LIMB',1,0),('L','A_LIMBM',1,0)]}
    for d in ('D','Q','Kv','F'):
        block=body.split('Dom::'+d+' => {',1)[1].split('}',1)[0]
        out[d]=read(block,d)
    block=body.split('Dom::S|Dom::Dd => {',1)[1]
    score=re.search(r'if dom==Dom::S \{(bytes[^}]+)\}',block)[1]
    division=re.search(r'if dom==division_dom \{([^}]+)\}',block)[1]
    out['S']=[('S','A_S8',1,127),('S','A_S8',-1,127)]+read(score,'S')
    out['Dd']=[]
    dest='Dd' if dd else 'S';out[dest]+=read(division,dest)
    return out

def cells(expressions,sources):
    # Independent row-major reference, signed two's-complement wrapping at
    # each Rust wrapping_mul/add. Every logical descriptor is evaluated.
    result=[[] for _ in expressions]
    if not expressions:return tuple()
    n=len(sources[expressions[0][1]])
    for x in range(n):
        for j,(_,source,coefficient,constant) in enumerate(expressions):
            product=(coefficient*sources[source][x])&0xffffffffffffffff
            value=(product+constant)&0xffffffffffffffff
            result[j].append(value if value<0x8000000000000000 else value-0x10000000000000000)
    return tuple(tuple(c) for c in result)

def histogram(cols):
    out=[0]*256;misses=0
    for col in cols:
        for v in col:
            if v<0 or v>255:out[0]+=1;misses+=1
            else:out[v]+=1
    return out,misses

P=2**64-2**32+1
def inverse(a):
    # Goldilocks quadratic extension: u^2=7.
    x,y=a;norm=(x*x-7*y*y)%P
    if not norm:return None
    v=pow(norm,-1,P);return (x*v%P,-y*v%P)
def add(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)

def helpers(cols,alpha,tag):
    output=[]
    for k in range(0,len(cols),2):
        col=[]
        for row in range(len(cols[k])):
            total=(0,0)
            # Native helper_pair asks first then second, including invalid
            # byte fallback. Never shortcut an equal pair's pole.
            for j in range(k,min(k+2,len(cols))):
                d=((alpha[0]-cols[j][row]-tag[0])%P,(alpha[1]-tag[1])%P)
                inv=inverse(d)
                if inv is None:return ('refused',k//2,j,row)
                total=add(total,inv)
            col.append(total)
        output.append(tuple(col))
    return tuple(output)
