"""Authored miniature loader; no native code, cryptographic capability or proof.

Only full-load same-invocation raw SHA reuse is new. Native reload stays on
the rebuilt-block digest. No cross-request cache and no metadata-only trust.
"""
import hashlib
import json
import struct

NAMES = ('wq','wk','wv','wo','gamma_a','gamma_m','wg_t','wu_t','wd_t')
DOMAIN = b'hashline/private-block-public/1'

def sha(b):
    return hashlib.sha256(b).hexdigest()

def specs(g):
    d,f,h,k,hd,dp,fp,hp,t = g
    q,kv=h*hd,k*hd
    return dict(zip(NAMES, [('i8',(q,d)),('i8',(kv,d)),('i8',(kv,d)),
        ('i8',(d,q)),('i8',(d,)),('i8',(d,)),('i8',(d,f)),
        ('i8',(d,f)),('i8',(f,d))])) | {
        'exp':('i64',(256,)), 'act':('i16',(256,)),
        'rope_cos':('i64',(t,hd//2)), 'rope_sin':('i64',(t,hd//2))}

def routes(g):
    d,f,h,k,hd,dp,fp,hp,t = g
    if not (d>0 and f>0 and hd>0 and hd%2==0 and h>0 and k>0 and h%k==0 and hp%k==0 and hp>=h and dp>=d and fp>=f):
        raise ValueError('geometry')
    q=h*hd; kv=k*hd; qp=hp*hd
    qi=tuple(((j//hd)//(h//k)*(hp//k)+(j//hd)%(h//k))*hd+j%hd for j in range(q))
    ident=lambda n:tuple(range(n))
    return dict(zip(NAMES,[(q,d,qp,dp,qi,ident(d)),
        (kv,d,kv,dp,ident(kv),ident(d)),(kv,d,kv,dp,ident(kv),ident(d)),
        (d,q,dp,qp,ident(d),qi),(1,d,1,dp,(0,),ident(d)),
        (1,d,1,dp,(0,),ident(d)),(d,f,dp,fp,ident(d),ident(f)),
        (d,f,dp,fp,ident(d),ident(f)),(f,d,fp,dp,ident(f),ident(d))]))

def identity_route(r):
    a,b,c,d,om,im=r
    return a==c and b==d and om==tuple(range(a)) and im==tuple(range(b))

def scatter(raw,r):
    a,b,c,d,om,im=r
    if len(raw)!=a*b or len(set(om))!=a or len(set(im))!=b:
        raise ValueError('mapping')
    out=bytearray(c*d)
    for o in range(a):
        for i in range(b):
            out[om[o]*d+im[i]]=raw[o*b+i]
    return bytes(out)

def load(g,layer,manifest_bytes,contents,full):
    m=json.loads(manifest_bytes)
    if m['layer']!=layer: raise ValueError('layer')
    expected=specs(g); loaded={}
    for name,(dt,shape) in expected.items():
        s=m['arrays'][name]
        if s['dtype']!=dt or tuple(s['shape'])!=shape: raise ValueError('dtype/shape')
        if '/' in s['file'] or '\\' in s['file'] or s['file'].startswith('.'):
            raise ValueError('plain name')
        n=1
        for v in shape: n*=v
        n*= {'i8':1,'i16':2,'i64':8}[dt]
        b=bytes(contents[s['file']])
        if len(b)!=n: raise ValueError('length')
        if full and sha(b)!=s['sha256']: raise ValueError('raw sha')
        loaded[name]=(b,s['sha256'] if full else None)
    return loaded

def construct_record(g,layer,manifest_bytes,contents,chunk=64,full=True):
    if chunk<=0: raise ValueError('chunk')
    rr=routes(g); loaded=load(g,layer,manifest_bytes,contents,full)
    # Native constructors check support then copy. Here construction has no
    # caller-supplied block or hash authority; both records refer to these bytes.
    block={n:scatter(loaded[n][0],rr[n]) for n in NAMES}
    for n in ('rope_cos','rope_sin','exp','act'): block[n]=loaded[n][0]
    words=[]; reused=[]; hashed_bytes=0
    for n in NAMES:
        if full and identity_route(rr[n]):
            words.append(loaded[n][1]);reused.append(n)
        else:
            h=hashlib.sha256()
            for j in range(0,len(block[n]),chunk): h.update(block[n][j:j+chunk])
            words.append(h.hexdigest());hashed_bytes+=len(block[n])
    h=hashlib.sha256();h.update(block['rope_cos']);h.update(block['rope_sin'])
    hashed_bytes+=len(block['rope_cos'])+len(block['rope_sin'])
    tables=[h.hexdigest()]
    for n in ('exp','act'):
        if full:
            tables.append(loaded[n][1]);reused.append(n)
        else:
            tables.append(sha(block[n]));hashed_bytes+=len(block[n])
    pre=bytearray(DOMAIN)
    for n in ('wq','wk','wv','wo','gamma_a','rope_cos','rope_sin','exp',
              'gamma_m','wg_t','wu_t','wd_t','act'):
        size=8 if n in ('rope_cos','rope_sin','exp') else 2 if n=='act' else 1
        pre.extend(struct.pack('<Q',len(block[n])//size));pre.extend(block[n])
    record={'layer':layer,'word_sha256':words,'table_sha256':tables,
            'manifest_sha256':sha(manifest_bytes),'canonical_preimage_sha256_SURROGATE':sha(pre)}
    return record,block,bytes(pre),{'reused':reused,'padded_sha_bytes':hashed_bytes}

def binding(profile,ordered_records):
    # Deliberately NOT a native statement serializer.
    return sha(json.dumps([profile,ordered_records],sort_keys=True,separators=(',',':')).encode())
