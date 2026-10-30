"""Independent destination-indexed signed-word reference, no candidate import."""
import hashlib
import json
import struct

def reference(g,layer,manifest_bytes,contents):
    width,hidden,qheads,kvheads,head,wp,fp,hpad,tokens=g
    if width<=0 or hidden<=0 or head%2 or qheads%kvheads or hpad%kvheads or hpad<qheads or wp<width or fp<hidden:
        raise ValueError('geometry')
    m=json.loads(manifest_bytes)
    if m['layer']!=layer: raise ValueError('layer')
    qwidth=qheads*head; kvwidth=kvheads*head; qp=hpad*head
    dims=[('wq',(qwidth,width),(qp,wp),'q','d'),
        ('wk',(kvwidth,width),(kvwidth,wp),'k','d'),
        ('wv',(kvwidth,width),(kvwidth,wp),'k','d'),
        ('wo',(width,qwidth),(wp,qp),'d','q'),
        ('gamma_a',(width,),(1,wp),'one','d'),
        ('gamma_m',(width,),(1,wp),'one','d'),
        ('wg_t',(width,hidden),(wp,fp),'d','f'),
        ('wu_t',(width,hidden),(wp,fp),'d','f'),
        ('wd_t',(hidden,width),(fp,wp),'f','d')]
    shape_map={n:('i8',s) for n,s,_,_,_ in dims}
    shape_map.update({'exp':('i64',(256,)),'act':('i16',(256,)),
        'rope_cos':('i64',(tokens,head//2)),'rope_sin':('i64',(tokens,head//2))})
    signed={}; source={}
    for n,(dt,s) in shape_map.items():
        meta=m['arrays'][n]
        if meta['dtype']!=dt or tuple(meta['shape'])!=s: raise ValueError('dtype/shape')
        if '/' in meta['file'] or '\\' in meta['file'] or meta['file'].startswith('.'): raise ValueError('plain name')
        raw=bytes(contents[meta['file']]); count=1
        for dim in s: count*=dim
        code={'i8':'b','i16':'h','i64':'q'}[dt]
        if len(raw)!=count*struct.calcsize(code): raise ValueError('length')
        if hashlib.sha256(raw).hexdigest()!=meta['sha256']: raise ValueError('raw sha')
        signed[n]=struct.unpack('<'+str(count)+code,raw);source[n]=raw
    def inverse(axis,j):
        if axis=='q':
            slot,offset=divmod(j,head); group,within=divmod(slot,hpad//kvheads)
            if within>=qheads//kvheads:return None
            return (group*(qheads//kvheads)+within)*head+offset
        limit={'d':width,'f':hidden,'k':kvwidth,'one':1}[axis]
        return j if j<limit else None
    out={}
    for n,true,pad,oa,ia in dims:
        stride=true[-1]; vals=[]
        for row in range(pad[0]):
            for col in range(pad[1]):
                r=inverse(oa,row);c=inverse(ia,col)
                vals.append(0 if r is None or c is None else signed[n][r*stride+c])
        out[n]=struct.pack('<'+str(len(vals))+'b',*vals)
    for n in ('rope_cos','rope_sin','exp','act'):
        code='h' if n=='act' else 'q'
        out[n]=b''.join(struct.pack('<'+code,v) for v in signed[n])
    word_names=[x[0] for x in dims]
    h=lambda b:hashlib.sha256(b).hexdigest()
    words=[h(out[n]) for n in word_names]
    tables=[h(out['rope_cos']+out['rope_sin']),h(out['exp']),h(out['act'])]
    order=('wq','wk','wv','wo','gamma_a','rope_cos','rope_sin','exp','gamma_m','wg_t','wu_t','wd_t','act')
    pre=b'hashline/private-block-public/1'
    for n in order:
        count=len(out[n])//(2 if n=='act' else 8 if n in ('rope_cos','rope_sin','exp') else 1)
        pre+=count.to_bytes(8,'little')+out[n]
    return {'layer':layer,'word_sha256':words,'table_sha256':tables,
        'manifest_sha256':h(manifest_bytes),'canonical_preimage_sha256_SURROGATE':h(pre)},out,pre
