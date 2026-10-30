"""Prepare isolated synthetic R-C2 app inputs from the pinned tied tensor.

No native proof is claimed here. Existing R-C1 artifacts remain immutable.
The small independent Python block is first checked against a retained native
sequence. Only public synthetic inputs are used in this development fixture.
"""
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys
from types import SimpleNamespace
import numpy as np

HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]
SOURCE=HERE/'classifier_fixture/prover-export'
DEST=HERE/'classifier_c2_fixture'
PRIVATE=Path('/tmp/zk60-astra-classifier-c2-20261029')
REF=ROOT/'results/zk60_token_io_r1_20261017/r13/dev_tied_reference.json'
sys.path.insert(0,str(ROOT/'results/zk60_shieldstral_export_20261026'))
import calibration_port as P

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,obj): p.write_text(json.dumps(obj,indent=2)+'\n')

def main():
    assert not DEST.exists() and not PRIVATE.exists(), 'fixture already exists; never overwrite'
    ref=json.loads(REF.read_text()); d=384; v=300
    s=0x746965642d646576; tensor=bytearray()
    for k in range(v*d+d):
        s=(s*6364136223846793005+1442695040888963407) & ((1<<64)-1); r=s>>33
        bits=(((r&1)<<15)|((120+(r>>1)%12)<<7)|((r>>5)&127)) if k<v*d else (((126+(r&1))<<7)|((r>>1)&127))
        tensor.extend(struct.pack('<H',bits))
    assert hashlib.sha256(tensor).hexdigest()==ref['tensor_sha256']
    vals=(np.frombuffer(tensor,dtype='<u2').astype('<u4')<<16).view('<f4').astype(np.float64)
    emb=np.floor(vals[:v*d].reshape(v,d)/ref['s_x']+0.5)
    margin=np.floor((vals[40*d:41*d]-vals[41*d:42*d])*vals[v*d:]/(1/256)+0.5)
    assert np.all((emb>=-32768)&(emb<=32767)) and np.all((margin>=-32767)&(margin<=32767))
    emb=emb.astype('<i2'); margin=margin.astype('<i2')
    assert hashlib.sha256(emb.tobytes()).hexdigest()==ref['embedding_sha256']
    assert hashlib.sha256(margin.tobytes()).hexdigest()==ref['margins']['rung-tc-synthetic-policy-dev/1']['sha256']
    directory=SOURCE/'layer_00'; meta=json.loads((directory/'manifest.json').read_text())
    words={}
    for key,info in meta['arrays'].items():
        p=directory/info['file']; assert sha(p)==info['sha256']
        words[key]=np.fromfile(p,dtype=np.dtype(info['dtype']).newbyteorder('<')).reshape(info['shape'])
    c=meta['constants']; geometry=SimpleNamespace(d=d,H=12,KV=4,G=3,dh=32,f=512)
    layer=P.tc.LayerInt(**{k:words[k] for k in ('wq','wk','wv','wo','gamma_a','gamma_m','wg_t','wu_t','wd_t','exp','act')},
        cn_a=c['norm_cn_a'],cn_m=c['norm_cn_m'],tn=c['norm_tn'],ceps=c['norm_ceps'],norm_wrho=P.tc.norm_window(d,c['norm_tn']),
        **{k:c[k] for k in ('sh_qkv','sh_rope','sh_s','sh_o','sh_ao','sh_g','sh_u','sh_h','sh_z','f_e','f_p','f_ro','sh_r2')})
    norm={'g0':127,'cn':2048,'tn':11,'ceps':33554467}
    def forward(x):
        rec=P.tc.Rec(1)
        y=P.tc.i_block(x.astype(np.int64)[None],layer,(words['rope_cos'],words['rope_sin']),rec,clamp=False,g=geometry)[0]
        assert rec.first[0] is None and np.all((y>=-32768)&(y<=32767)), 'candidate block refused'
        return y.astype('<i2')
    old_in=np.fromfile(SOURCE/'seq_s0/x_in_L00.bin',dtype='<i2').reshape(32,d)
    old_out=np.fromfile(SOURCE/'seq_s0/x_out_L00.bin',dtype='<i2').reshape(32,d)
    assert np.array_equal(forward(old_in),old_out), 'independent kernel differs from retained native sequence'
    def evaluate(ids):
        x=emb[list(range(1,9))+list(ids)+[32]]; y=forward(x); rec=P.tc.Rec(1)
        z,_=P.tc.i_norm(y.astype(np.int64)[None,-1:],np.full(d,127,dtype=np.int8),2048,11,33554467,32,rec,'final_norm',0,False)
        assert rec.first[0] is None, 'candidate final norm refused'
        return x,y,int(z.reshape(-1)@margin.astype(np.int64))
    # The model-derived margin is immutable; vary only synthetic content.
    # Record the observed verdict coverage without inventing a second policy
    # (the native CLI registers only the original development policy).
    cases=[]; seen=set(); rng=np.random.default_rng(20261029)
    candidates=[list(range(9,32))]+[rng.integers(5,v,size=23).tolist() for _ in range(31)]
    candidates += [[token]*23 for token in range(5,v)]
    dots=[]
    for ids in candidates:
        x,y,dot=evaluate(ids); bit=int(dot>0)
        dots.append(dot)
        if bit not in seen:
            cases.append({'name':'positive' if bit else 'negative','content_ids':ids,'arrays':[(x,y)],'margins':[dot]});seen.add(bit)
        if len(seen)==2:break
    content=list(range(9,32))+[33,34,35,36]
    evaluated=[evaluate(content[a:b]) for a,b in [(0,23),(4,27)]]
    cases.append({'name':'multi','content_ids':content,'arrays':[(x,y) for x,y,_ in evaluated],'margins':[dot for _,_,dot in evaluated]})
    DEST.mkdir(); PRIVATE.mkdir(mode=0o700)
    shutil.copytree(SOURCE,DEST/'prover-export',ignore=shutil.ignore_patterns('seq_*'))
    profile=json.loads((DEST/'prover-export/profile.json').read_text())
    profile.update(variant='astra-retained-rung-c2',residual_unit=ref['s_x'],
        token_io_parameters={'bos':1,'classifier_final_norm':norm,'head_final_norm':norm},
        classifier_margin_parameters={'yes_id':40,'no_id':41,'public_scale':1/256,'threshold_c':0})
    save(DEST/'prover-export/profile.json',profile)
    shutil.copytree(DEST/'prover-export',DEST/'verifier-export')
    tables=DEST/'tables';tables.mkdir()
    for name,data in [('dev_tied_tensor_bf16.bin',tensor),('embedding_int16.bin',emb.tobytes()),('margin_int16.bin',margin.tobytes())]:
        (tables/name).write_bytes(data)
    save(tables/'token_io.json',{'bos':1,'embedding_table':{'dtype':'int16','file':'embedding_int16.bin','shape':[v,d],'sha256':sha(tables/'embedding_int16.bin')}})
    save(tables/'classifier.json',{'schema':'zk60-classifier-tables/1','bos':1,'final_norm':norm,'yes_id':40,'no_id':41,'threshold_c':0,
        'margin_vector':{'dtype':'int16','file':'margin_int16.bin','sha256':sha(tables/'margin_int16.bin'),'d':d,'scale':1/256}})
    for case in cases:
        case['sequence_dirs']=[];case['sequence_sha256']=[]
        for index,(x,y) in enumerate(case.pop('arrays')):
            seq=PRIVATE/(case['name']+'-seq-'+str(index));seq.mkdir(mode=0o700)
            for name,array in [('x_in_L00.bin',x),('x_out_L00.bin',y)]:
                p=seq/name;p.write_bytes(array.tobytes());p.chmod(0o600)
            case['sequence_dirs'].append(str(seq));case['sequence_sha256'].append({p.name:sha(p) for p in seq.iterdir()})
    manifest={'schema':'pm-r-c2-development-fixture/1','scope':'Synthetic candidates; native proof and fresh verification still required',
        'reference_sha256':sha(REF),'tool_sha256':sha(Path(__file__)),'integer_kernel_sha256':sha(Path(P.tc.__file__)),
        'source_profile_sha256':sha(SOURCE/'profile.json'),'retained_native_python_parity':True,'private_root':str(PRIVATE),'cases':cases,
        'candidate_search':{'inputs':len(dots),'margin_min':min(dots),'margin_max':max(dots),'verdict_bits':sorted(seen),
                            'limit':'This fixture claims only the observed native verdict coverage, not both verdict branches.'},
        'files':{str(p.relative_to(DEST)):sha(p) for p in DEST.rglob('*') if p.is_file()}}
    save(DEST/'fixture.json',manifest)
    print(json.dumps({'prepared':True,'cases':[{k:c[k] for k in ('name','margins')} for c in cases], 'native_proof_pending':True}))

if __name__=='__main__':main()
