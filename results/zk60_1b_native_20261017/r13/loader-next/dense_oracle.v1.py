"""Independent exact integer reference for public dense decoupled-Q fixtures."""
import os
os.environ['OPENBLAS_NUM_THREADS']='1'
os.environ['OMP_NUM_THREADS']='1'
from pathlib import Path
import hashlib
import json
import math
import numpy as np

root=Path(__file__).resolve().parent.parent/'loader-fixtures'
sha=lambda b:hashlib.sha256(b).hexdigest()

def bounded(name,words,lo,hi):
    assert np.all((words>=lo)&(words<=hi)),(name,int(words.min()),int(words.max()),lo,hi)
    return words

def rq(acc,shift,mult=1):
    shift=np.asarray(shift,dtype=np.int64)
    den=np.left_shift(np.int64(1),shift)
    # All operations below are exact int64; refuse before multiplication if
    # the public fixture's measured operand bound cannot fit that carrier.
    assert int(np.max(np.abs(acc)))*int(np.max(np.abs(mult)))+int(np.max(den))//2 < (1<<63)
    return (acc*mult+den//2)//den

def norm(x,gain,cn,tn,ceps):
    ds=np.asarray([math.isqrt(ceps+sum(int(v)*int(v) for v in row)) for row in x],dtype=np.int64)[:,None]
    assert np.all(ds>0)
    dv=ds*(1<<tn);den=2*dv;numerator=2*x*gain*cn+dv
    y=numerator//den;rho=numerator-den*y;sigma=den-1-rho
    bounded('norm rho',rho,0,(1<<24)-1);bounded('norm sigma',sigma,0,(1<<24)-1)
    return bounded('norm word',y,-32768,32767)

def rotate(x,heads,cos,sin):
    raw=x.reshape(32,heads,64);a,b=raw[:,:,:32],raw[:,:,32:]
    c,s=cos[:,None,:],sin[:,None,:]
    return np.concatenate((rq(a*c-b*s,7),rq(b*c+a*s,7)),axis=-1).reshape(32,heads*64)

reports=[]
for entry in json.loads((root/'DENSE_CATALOG.json').read_text()):
    path=root/entry['variant'];pb=(path/'profile.json').read_bytes();assert sha(pb)==entry['profile_sha256']
    p=json.loads(pb);layer=path/'layer_00';mb=(layer/'manifest.json').read_bytes()
    assert sha(mb)==entry['layer_manifest_sha256']==p['layers'][0]['manifest_sha256']
    manifest=json.loads(mb);c=manifest['constants'];arrays={}
    for key,spec in manifest['arrays'].items():
        raw=(layer/spec['file']).read_bytes();assert sha(raw)==spec['sha256']
        dtype={'int8':'i1','int16':'<i2','int64':'<i8'}[spec['dtype']]
        arrays[key]=np.frombuffer(raw,dtype=dtype).reshape(spec['shape']).astype(np.int64)
    assert (arrays['wq'].shape,arrays['wk'].shape,arrays['wg_t'].shape)==((1024,384),(512,384),(384,768))
    for key in ['wq','wk','wv','wo','wg_t','wu_t','wd_t']:assert np.all(arrays[key]!=0)
    raw=(path/'seq_public/x_in_L00.bin').read_bytes();assert sha(raw)==entry['input_sha256']
    x=np.frombuffer(raw,dtype='<i2').reshape(32,384).astype(np.int64)
    trace={'input':x};h24=p['accuracy_stack']=='low-h24-v1';extra=8 if h24 else 0
    y=norm(x,arrays['gamma_a'],c['norm_cn_a'],c['norm_tn']-8,c['norm_ceps']);trace['y']=y
    for name,bump in [('q',7),('k',7),('v',8)]:
        trace[name]=bounded(name,rq(y@arrays['w'+name].T,c['sh_qkv']+bump,arrays['m_'+name]),-32768,32767)
    cos=np.asarray([[math.floor(128*math.cos(t*10000**(-2*i/64))+.5) for i in range(32)] for t in range(32)],dtype=np.int64)
    sin=np.asarray([[math.floor(128*math.sin(t*10000**(-2*i/64))+.5) for i in range(32)] for t in range(32)],dtype=np.int64)
    qr=bounded('qr',rotate(trace['q'],16,cos,sin),-32768,32767).reshape(32,16,64)
    kr=bounded('kr',rotate(trace['k'],8,cos,sin),-32768,32767).reshape(32,8,64)
    trace['qr']=qr.reshape(32,1024);trace['kr']=kr.reshape(32,512)
    scores=np.stack([rq(qr[:,h,:]@kr[:,h//2,:].T,c['sh_s']+12) for h in range(16)])
    bounded('all scores incl future',scores,-127,127);trace['s']=scores
    mask=np.tril(np.ones((32,32),dtype=bool));masked=np.where(mask,scores,-127)
    maximum=masked.max(axis=-1,keepdims=True);delta=maximum-masked
    bounded('exp index',delta,0,255);e=arrays['exp'][delta]
    denom=np.where(mask,e,0).sum(axis=-1,keepdims=True)
    assert np.all(denom>0)
    probability=(np.where(mask,e,0)*(1<<12))//denom;trace['p']=probability
    v=trace['v'].reshape(32,8,64)
    o=np.stack([rq(probability[h]@v[:,h//2,:],c['sh_o']+3) for h in range(16)],axis=1).reshape(32,1024)
    trace['o']=bounded('o',o,-32768,32767)
    ao=bounded('ao',rq(o@arrays['wo'].T,c['sh_ao']+14,arrays['m_o']),-32768,32767);trace['ao']=ao
    x1=bounded('x1',x+ao,-32768,32767);trace['x1']=x1
    nm=norm(x1,arrays['gamma_m'],c['norm_cn_m'],c['norm_tn']-8,c['norm_ceps']);trace['nm']=nm
    ids=arrays['silu_group_ids'];groups=arrays['silu_groups'];ein,eout=map(int,c['silu_member'])
    gate_shift=c['sh_g']+10+groups[ids,0]-ein
    gate=bounded('gate',rq(nm@arrays['wg_t'],gate_shift,arrays['m_g']),-2048,2047);trace['gate']=gate
    raw_act=arrays['act'][ids[None,:],gate+2048];trace['a_group']=raw_act
    delta_out=groups[ids,1]-eout
    scaled=raw_act*np.left_shift(np.int64(1),24-c['sh_h']+delta_out);trace['a_scaled']=scaled
    up=bounded('up',rq(nm@arrays['wu_t'],12,arrays['m_u']),-32768,32767);trace['up']=up
    h=bounded('h',rq(raw_act*up,c['sh_h']-extra-delta_out),-(1<<(15+extra)),(1<<(15+extra))-1);trace['h']=h
    # A second representation must agree exactly, including negative ties.
    assert np.array_equal(h,rq(scaled*up,16 if h24 else 24))
    z=bounded('z',rq(h@arrays['wd_t'],c['sh_z']+6+extra,arrays['m_d']),-32768,32767);trace['z']=z
    x2=bounded('x2',x1+z,-32768,32767);trace['x2']=x2
    flat=''.join(name+'\t'+'\t'.join(map(str,values.reshape(-1).tolist()))+'\n' for name,values in trace.items())
    (path/'independent_trace.tsv').write_text(flat)
    output=x2.astype('<i2').tobytes();(path/'seq_public/x_out_L00.bin').write_bytes(output)
    seq_arrays={name:{'file':name+'.bin','dtype':'int16','shape':[32,384],'sha256':sha(data)}
        for name,data in [('x_in_L00',raw),('x_out_L00',output)]}
    (path/'seq_public/manifest.json').write_text(json.dumps({'kind':'sequence','arrays':seq_arrays},indent=2)+'\n')
    reports.append({'variant':entry['variant'],'scope':'independent exact public synthetic integer reference; native comparison/proof pending',
        'script_sha256':sha(Path(__file__).read_bytes()),'profile_sha256':sha(pb),'input_sha256':sha(raw),'output_sha256':sha(output),
        'trace_sha256':sha(flat.encode()),'ranges':{k:[int(v.min()),int(v.max())] for k,v in trace.items()},
        'decoupled_axes':{'model_width':384,'query_width':1024,'kv_width':512,'hidden':768},'violations':0})
(root/'DENSE_ORACLE.json').write_text(json.dumps(reports,indent=2)+'\n')
print(json.dumps(reports))
