"""Authored synthetic public-only model; not native code or a capability implementation."""
from dataclasses import dataclass
import hashlib, json, math, os, stat, struct

def sha(b): return hashlib.sha256(b).hexdigest()
def wire(x): return json.dumps(x,sort_keys=True,separators=(',',':')).encode()
def read_regular(path, size=None):
    before=os.lstat(path)
    if not stat.S_ISREG(before.st_mode): raise ValueError('regular')
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    with os.fdopen(fd,'rb') as f:
        after=os.fstat(f.fileno())
        if (before.st_dev,before.st_ino,before.st_size)!=(after.st_dev,after.st_ino,after.st_size): raise ValueError('identity')
        if size is not None and after.st_size!=size: raise ValueError('size')
        if after.st_size>1<<20: raise ValueError('synthetic bound')
        b=f.read(after.st_size+1)
        if len(b)!=after.st_size: raise ValueError('length')
    return b
def values(b):
    out=[struct.unpack('<f',b'\0\0'+b[i:i+2])[0] for i in range(0,len(b),2)]
    if len(b)%2 or any(not math.isfinite(x) for x in out): raise ValueError('bf16')
    return out
def rotate(v,signs,block):
    if len(v)!=len(signs) or block<=0 or block&(block-1) or len(v)%block or any(x not in (-1.,1.) for x in signs): raise ValueError('rotation')
    out=[a*b for a,b in zip(v,signs)]
    for start in range(0,len(out),block):
        step=1
        while step<block:
            for base in range(start,start+block,step*2):
                for k in range(step):
                    a,b=out[base+k],out[base+k+step]
                    out[base+k],out[base+k+step]=a+b,a-b
            step*=2
        for k in range(start,start+block):out[k]/=math.sqrt(block)
    return out
def quant(v,scale,low,high):
    if not math.isfinite(scale) or scale<=0: raise ValueError('scale')
    out=[]
    for x in v:
        y=x/scale+0.5
        if not math.isfinite(y): raise ValueError('nonfinite')
        q=math.floor(y)
        if not low<=q<=high:raise ValueError('overflow')
        out.append(q)
    return out
def extent(h,name,shape,size,base):
    t=h[name];lo,hi=t['data_offsets']
    if t['dtype']!='BF16' or t['shape']!=shape or lo<0 or hi-lo!=math.prod(shape)*2 or hi>size-base:raise ValueError('extent')
    return base+lo,hi-lo

@dataclass(frozen=True)
class Derived:
    profile: str
    checkpoint: str
    sign_digest: str
    algorithm: str
    digests: tuple
    margin: tuple
    calibration: bytes
    def use(self,profile_bytes,expected_profile,algorithm='synthetic-r12b-1'):
        if sha(profile_bytes)!=expected_profile or expected_profile!=self.profile or algorithm!=self.algorithm:raise ValueError('binding')
        return self.digests,self.margin,self.calibration

def derive(profile_bytes,sign_bytes,checkpoint_bytes,phase2=None):
    p=json.loads(profile_bytes);v,w,b=p['vocab'],p['width'],p['block']
    m=p['margin'];yes,no,ms=m['yes'],m['no'],m['scale']
    if yes==no or not 0<=yes<v or not 0<=no<v:raise ValueError('ids')
    for s in (ms,p['residual_scale']):
        if not math.isfinite(s) or s<=0:raise ValueError('scale')
    if sha(sign_bytes)!=p['sign_sha256']:raise ValueError('sign pin')
    signs=list(struct.unpack('<'+'d'*w,sign_bytes))
    n=struct.unpack('<Q',checkpoint_bytes[:8])[0];base=8+n
    h=json.loads(checkpoint_bytes[8:base])
    off,length=extent(h,'embedding',[v,w],len(checkpoint_bytes),base)
    normoff,normlen=extent(h,'norm',[w],len(checkpoint_bytes),base)
    if 'lm_head' in h:raise ValueError('untied')
    if len(checkpoint_bytes)!=p['checkpoint_size'] or sha(checkpoint_bytes)!=p['checkpoint_sha256']:raise ValueError('checkpoint pin')
    norm=values(checkpoint_bytes[normoff:normoff+normlen]) # same authenticated bytes
    consumed=checkpoint_bytes if phase2 is None else phase2
    tensor=consumed[off:off+length]
    if sha(tensor)!=p['tensor_sha256']:raise ValueError('consumed tensor pin')
    emb=bytearray();head=bytearray();scales=[];wanted={}
    for r in range(v):
        row=values(tensor[r*w*2:(r+1)*w*2])
        if r in (yes,no):wanted[r]=row
        e=[struct.unpack('<f',struct.pack('<f',x))[0] for x in rotate(row,signs,b)]
        emb.extend(struct.pack('<'+'h'*w,*quant(e,p['residual_scale'],-32768,32767)))
        f=rotate([x*g for x,g in zip(row,norm)],signs,b)
        scale=max(abs(x) for x in f)/127.;scales.append(scale)
        head.extend(x%256 for x in quant(f,scale if scale>0 else 1.,-127,127))
    maximum=max(scales)
    if maximum<=0:raise ValueError('maximum')
    mult=b''.join(struct.pack('<q',max(1,math.floor(4096*s/maximum+0.5))) for s in scales)
    delta=rotate([(a-c)*g for a,c,g in zip(wanted[yes],wanted[no],norm)],signs,b)
    margin=tuple(quant(delta,ms,-32767,32767))
    return Derived(sha(profile_bytes),p['checkpoint_sha256'],sha(sign_bytes),'synthetic-r12b-1',(sha(emb),sha(head),sha(mult)),margin,wire(p['calibration']))

def validate_tables(derived,tables):
    if tuple(sha(x) for x in tables)!=derived.digests:raise ValueError('table mismatch')
