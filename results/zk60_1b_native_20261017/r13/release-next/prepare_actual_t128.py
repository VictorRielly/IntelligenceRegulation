"""One actual public layer at T128, with an independent public-input oracle.

The source is the losslessly converted 26-layer S2 export. Only the public
context length and RoPE prefix change; integer weights/calibration stay exact.
This is a one-block implementation smoke, not model fidelity or stack coverage.
"""
from pathlib import Path
import hashlib
import json
import math
import shutil
import numpy as np

HERE=Path(__file__).resolve().parents[1]
SOURCE=HERE/'shieldstral-export-v2'
OUT=HERE/'actual-t128-smoke-export'
SEQ=HERE/'actual-t128-public-sequence'

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()

def dump(path,value):path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')

def bounded(name,a,lo,hi):
    assert np.all((a>=lo)&(a<=hi)),(name,int(a.min()),int(a.max()),lo,hi)
    return a

def rq(a,shift,m=1):
    den=np.left_shift(np.int64(1),np.asarray(shift,dtype=np.int64))
    assert int(np.abs(a).max())*int(np.abs(m).max())+int(den.max())//2 < 1<<63
    return (a*m+den//2)//den

def norm(x,gamma,cn,tn,eps):
    d=np.array([math.isqrt(eps+sum(int(v)**2 for v in row)) for row in x],dtype=np.int64)[:,None]
    dv=d*(1<<tn);den=2*dv;num=2*x*gamma*cn+dv;y=num//den
    bounded('norm rho',num-den*y,0,(1<<24)-1)
    bounded('norm sigma',den-1-(num-den*y),0,(1<<24)-1)
    return bounded('norm word',y,-32768,32767)

def main():
    assert sha(SOURCE/'profile.json')=='1d50078243f13d58afa814a55c47c2df797e494d7f045941ea82fa142740498a'
    assert not OUT.exists() and not SEQ.exists(),'retain existing candidate and oracle evidence'
    OUT.mkdir();SEQ.mkdir();layer=OUT/'layer_00';layer.mkdir()
    p=json.loads((SOURCE/'profile.json').read_text());m=json.loads((SOURCE/'layer_00/manifest.json').read_text())
    arrays={}
    for name,spec in m['arrays'].items():
        src=SOURCE/'layer_00'/spec['file'];assert sha(src)==spec['sha256']
        dtype={'int8':'i1','int16':'<i2','int64':'<i8'}[spec['dtype']]
        a=np.fromfile(src,dtype=dtype).reshape(spec['shape'])
        if name in ['rope_cos','rope_sin']:a=a[:128].copy();spec['shape']=list(a.shape)
        a.tofile(layer/spec['file']);spec['sha256']=sha(layer/spec['file'])
        arrays[name]=a
    m['tables']['rope']['t_max']=128
    # The old combined table digest applies to T256; hashes above bind the
    # exact T128 arrays and the native loader recomputes the approved YaRN.
    m['tables']['rope'].pop('spec_digest',None)
    dump(layer/'manifest.json',m)
    p.update(T=128,geometry='shieldstral-3b-t128',variant='shieldstral-s2-L00-t128-public-smoke',
             layers=[{'layer':0,'dir':'layer_00','manifest_sha256':sha(layer/'manifest.json')}],
             scope='one actual S2 public layer, public synthetic input, T128; no model fidelity or full-stack proof claim')
    p['r13_t128_smoke']={'source_profile_sha256':sha(SOURCE/'profile.json'),'adapter_sha256':sha(Path(__file__)),
                        'change':'T256 -> T128 and exact first128 YaRN rows; no weight/calibration requantization'}
    td=OUT/'token_io';td.mkdir()
    for name in ['embedding_int16.bin','head_int8_perrow.bin','head_mult12.bin','head_manifest.json','token_io.json']:
        shutil.copyfile(SOURCE/'token_io'/name,td/name)
    tio=json.loads((td/'token_io.json').read_text());tio['T']=128;dump(td/'token_io.json',tio)
    shutil.copyfile(SOURCE/'rotation_sign.bin',OUT/'rotation_sign.bin');dump(OUT/'profile.json',p)
    c=m['constants'];T,D,H,KV,HD,F=128,3072,32,8,128,9216
    x=np.zeros((T,D),dtype=np.int64)
    for t in range(T):
        for j in range(32):x[t,(j*97+t*13)%D]=1 if (j+t)%2 else -1
    trace={'input':x};y=norm(x,arrays['gamma_a'],c['norm_cn_a'],c['norm_tn']-8,c['norm_ceps']);trace['y']=y
    for name,bump in [('q',7),('k',7),('v',8)]:
        trace[name]=bounded(name,rq(y@arrays['w'+name].T,c['sh_qkv']+bump,arrays['m_'+name]),-32768,32767)
    def rotate(words,heads):
        words=words.reshape(T,heads,HD);a,b=words[:,:,:HD//2],words[:,:,HD//2:]
        co=arrays['rope_cos'][:,None,:];si=arrays['rope_sin'][:,None,:]
        return bounded('RoPE',np.concatenate((rq(a*co-b*si,7),rq(b*co+a*si,7)),axis=-1),-32768,32767)
    qr=rotate(trace['q'],H);kr=rotate(trace['k'],KV);trace.update(qr=qr,kr=kr)
    score=np.stack([rq(qr[:,h,:]@kr[:,h//(H//KV),:].T,c['sh_s']+12) for h in range(H)])
    bounded('all scores incl future',score,-127,127);trace['s']=score
    mask=np.tril(np.ones((T,T),dtype=bool));masked=np.where(mask,score,-127)
    delta=masked.max(axis=-1,keepdims=True)-masked;bounded('exp index',delta,0,255)
    e=np.where(mask,arrays['exp'][delta],0);total=e.sum(axis=-1,keepdims=True);assert np.all(total>0)
    probability=(e*(1<<12))//total;trace['p']=probability
    v=trace['v'].reshape(T,KV,HD)
    o=np.stack([rq(probability[h]@v[:,h//(H//KV),:],c['sh_o']+3) for h in range(H)],axis=1).reshape(T,H*HD)
    trace['o']=bounded('o',o,-32768,32767)
    ao=bounded('ao',rq(o@arrays['wo'].T,c['sh_ao']+14,arrays['m_o']),-32768,32767);trace['ao']=ao
    x1=bounded('x1',x+ao,-32768,32767);trace['x1']=x1
    nm=norm(x1,arrays['gamma_m'],c['norm_cn_m'],c['norm_tn']-8,c['norm_ceps']);trace['nm']=nm
    ids=arrays['silu_group_ids'];groups=arrays['silu_groups'];ein,eout=c['silu_member']
    gate=bounded('gate',rq(nm@arrays['wg_t'],c['sh_g']+10+groups[ids,0]-ein,arrays['m_g']),-2048,2047);trace['gate']=gate
    raw=arrays['act'][ids[None,:],gate+2048].astype(np.int64);delta_out=groups[ids,1]-eout
    scaled=raw*np.left_shift(np.int64(1),24-c['sh_h']+delta_out);trace['a_scaled']=scaled
    up=bounded('up',rq(nm@arrays['wu_t'],12,arrays['m_u']),-32768,32767);trace['up']=up
    h=bounded('h',rq(raw*up,c['sh_h']-8-delta_out),-(1<<23),(1<<23)-1);trace['h']=h
    assert np.array_equal(h,rq(scaled*up,16))
    z=bounded('z',rq(h@arrays['wd_t'],c['sh_z']+14,arrays['m_d']),-32768,32767);trace['z']=z
    trace['x2']=bounded('x2',x1+z,-32768,32767)
    specs={}
    for name,value in [('x_in_L00',x),('x_out_L00',trace['x2'])]:
        f=SEQ/(name+'.bin');value.astype('<i2').tofile(f)
        specs[name]={'file':f.name,'dtype':'int16','shape':[T,D],'sha256':sha(f)}
    dump(SEQ/'manifest.json',{'kind':'public synthetic sequence','arrays':specs})
    dump(OUT/'PUBLIC_ORACLE.json',{'script_sha256':sha(Path(__file__)),'profile_sha256':sha(OUT/'profile.json'),
        'source_profile_sha256':sha(SOURCE/'profile.json'),'violations':0,'trace_sites':len(trace),
        'ranges':{k:[int(v.min()),int(v.max())] for k,v in trace.items()},
        'trace_sha256':{k:hashlib.sha256(np.asarray(v,dtype='<i8').tobytes()).hexdigest() for k,v in trace.items()},
        'scope':p['scope']})
    print(json.dumps({'profile_sha256':sha(OUT/'profile.json'),'oracle_sha256':sha(OUT/'PUBLIC_ORACLE.json'),
                      'violations':0,'trace_sites':len(trace),'scope':p['scope']}),flush=True)

if __name__=='__main__':main()
