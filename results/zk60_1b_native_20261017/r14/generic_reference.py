"""Independent integer arithmetic on the public dense-fixture inputs.

Reads native-dumped PUBLIC matrices/constants. Never reads native internal
witness words until comparing the completed independent trace. This tests
the S2 integer operations, not the already-reviewed public table generators.
Run separately through the common resource guard.
"""
import hashlib,json,math,sys
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent
T,D,Q,KV,HD,F,DP,FP=128,3072,4096,8,128,9216,4096,16384
def rq(a,shift,m=1):
    den=np.left_shift(np.int64(1),np.asarray(shift,dtype=np.int64))
    assert int(np.abs(a).max())*int(np.abs(m).max())+int(den.max())//2<1<<63
    return (a*m+den//2)//den
def bounded(name,a,lo,hi):
    assert np.all((a>=lo)&(a<=hi)),(name,int(a.min()),int(a.max()),lo,hi)
    return a
def norm(x,gamma):
    den=np.array([math.isqrt(1+sum(int(v)**2 for v in row)) for row in x],dtype=np.int64)[:,None]*2
    return bounded('norm',(2*x*gamma*100+den)//(2*den),-32768,32767)
def main():
    directory=Path(sys.argv[1]);out=Path(sys.argv[2]);assert not out.exists()
    def read(name,dtype,shape):
        p=directory/name;assert p.is_file() and p.stat().st_size==np.dtype(dtype).itemsize*math.prod(shape)
        return np.fromfile(p,dtype=dtype).reshape(shape)
    weights={
        'q':read('wq.i8','i1',(Q,DP))[:,:D],
        'k':read('wk.i8','i1',(KV*HD,DP))[:,:D],
        'v':read('wv.i8','i1',(KV*HD,DP))[:,:D],
        'o':read('wo.i8','i1',(DP,Q))[:D,:],
        'g':read('wg_t.i8','i1',(DP,FP))[:D,:F],
        'u':read('wu_t.i8','i1',(DP,FP))[:D,:F],
        'd':read('wd_t.i8','i1',(FP,DP))[:F,:D],
    }
    mult={k:read('m_'+k+'.u16','<u2',(n,)).astype(np.int64) for k,n in [('q',Q),('k',KV*HD),('v',KV*HD),('o',D),('g',F),('u',F),('d',D)]}
    gamma_a=read('gamma_a.i8','i1',(DP,))[:D];gamma_m=read('gamma_m.i8','i1',(DP,))[:D]
    ids=read('group_ids.i64','<i8',(F,));groups=read('groups.i32','<i4',(2,2));raw_act=read('act.i16','<i2',(2,4096))
    exp=read('exp.i64','<i8',(256,));co=read('rope_cos.i64','<i8',(T,HD//2));si=read('rope_sin.i64','<i8',(T,HD//2))
    # The input is public and independently regenerated from the stated seed.
    t=np.arange(T,dtype=np.uint64)[:,None];j=np.arange(D,dtype=np.uint64)[None,:]
    bits=((t*1103515245+j*12345+(t^j)*2654435761+809)&np.uint64(0xffffffff))>>16
    x=np.where((bits&1)==0,-1,1).astype(np.int64)
    trace={'input':x};y=norm(x,gamma_a);trace['y']=y
    for name,shift in [('q',9),('k',9),('v',10)]:
        trace[name]=bounded(name,rq(y@weights[name].T,shift,mult[name]),-32768,32767)
    def rotate(words,heads):
        w=words.reshape(T,heads,HD);a,b=w[:,:,:HD//2],w[:,:,HD//2:]
        return bounded('rotate',np.concatenate((rq(a*co[:,None,:]-b*si[:,None,:],7),rq(b*co[:,None,:]+a*si[:,None,:],7)),axis=-1),-32768,32767)
    qr=rotate(trace['q'],32);kr=rotate(trace['k'],KV);trace.update(qr=qr,kr=kr)
    scores=np.stack([rq(qr[:,h,:]@kr[:,h//4,:].T,19) for h in range(32)])
    trace['s']=bounded('scores',scores,-127,127);assert scores.min()<0<scores.max()
    causal=np.tril(np.ones((T,T),dtype=bool));masked=np.where(causal,scores,-127)
    delta=masked.max(axis=-1,keepdims=True)-masked;bounded('exp index',delta,0,255)
    e=np.where(causal,exp[delta],0);total=e.sum(axis=-1,keepdims=True);assert np.all(total>0)
    p=(e*(1<<12))//total;trace['p']=p
    v=trace['v'].reshape(T,KV,HD)
    o=np.stack([rq(p[h]@v[:,h//4,:],12) for h in range(32)],axis=1).reshape(T,Q)
    trace['o']=bounded('o',o,-32768,32767)
    ao=bounded('ao',rq(o@weights['o'].T,21,mult['o']),-32768,32767);trace['ao']=ao
    x1=bounded('x1',x+ao,-32768,32767);trace['x1']=x1
    nm=norm(x1,gamma_m);trace['nm']=nm
    gate=bounded('gate',rq(nm@weights['g'],18+groups[ids,0]-(-3),mult['g']),-2048,2047);trace['gate']=gate
    raw=raw_act[ids[None,:],gate+2048].astype(np.int64)
    a_scaled=raw*np.left_shift(np.int64(1),10+groups[ids,1]-(-11));trace['a_scaled']=a_scaled
    up=bounded('up',rq(nm@weights['u'],12,mult['u']),-32768,32767);trace['up']=up
    h=bounded('h',rq(a_scaled*up,16),-(1<<23),(1<<23)-1);trace['h']=h
    z=bounded('z',rq(h@weights['d'],20,mult['d']),-32768,32767);trace['z']=z
    trace['x2']=bounded('x2',x1+z,-32768,32767)
    rows=[]
    for name,value in trace.items():
        expected=np.asarray(value,dtype='<i8').reshape(-1)
        actual=read(name+'.i64','<i8',(expected.size,))
        different=int(np.count_nonzero(expected!=actual))
        assert different==0,(name,different)
        rows.append({'site':name,'words':expected.size,'differences':different,
            'sha256':hashlib.sha256(expected.tobytes()).hexdigest(),'range':[int(expected.min()),int(expected.max())]})
    assert len(rows)==19
    report={'scope':'Independent exact S2 integer arithmetic against native generic dense public synthetic fixture. Public native matrix/table constants are inputs; table generators were reviewed separately at R13. Not trained-model or privacy acceptance.',
        'sites':rows,'differences':0,'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'sites':19,'differences':0,'output':str(out)}))
if __name__=='__main__':main()
