"""T128 causal prefix of the reviewer's accepted actual-L25 numeric oracle.

Reads retained T256 arithmetic reference data; launches no T256 proof. No
native/source/other-lane files are changed. The input is a numerical review
fixture, separate from the app's private per-item activation workspace.
"""
from datetime import datetime,timezone
import hashlib,json
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
REVIEW=ROOT/'results/zk60_d24_review_20261017/r13'
FULL=ROOT/'results/zk60_shieldstral_export_20261026/native_low_h24_t128'
OLD=HERE.parent/'r13/shieldstral-export-v2'
OUT=HERE/'l25-causal-prefix'
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1<<20),b''):h.update(block)
    return h.hexdigest()
def main():
    assert not OUT.exists()
    p=FULL/'profile.json';assert sha(p)=='2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0'
    old=OLD/'profile.json';assert sha(old)=='1d50078243f13d58afa814a55c47c2df797e494d7f045941ea82fa142740498a'
    profile=json.loads(p.read_text());source=json.loads(old.read_text())
    entry=next(l for l in profile['layers'] if l['layer']==25);prior=next(l for l in source['layers'] if l['layer']==25)
    mp=FULL/entry['dir']/'manifest.json';op=OLD/prior['dir']/'manifest.json'
    assert sha(mp)==entry['manifest_sha256'] and sha(op)==prior['manifest_sha256']
    m=json.loads(mp.read_text());o=json.loads(op.read_text());assert m['constants']==o['constants']
    assert set(m['arrays'])==set(o['arrays'])
    for key,spec in m['arrays'].items():
        if key not in ['rope_cos','rope_sin']:assert spec['sha256']==o['arrays'][key]['sha256'],key
        else:
            a=np.fromfile(mp.parent/spec['file'],dtype='<i8').reshape(spec['shape'])
            b=np.fromfile(op.parent/o['arrays'][key]['file'],dtype='<i8').reshape(o['arrays'][key]['shape'])
            assert np.array_equal(a,b[:128]),key
    compare=REVIEW/'compare_shield_L25.json';assert json.loads(compare.read_text())['all_equal'] is True
    reference=REVIEW/'ref_shield_L25.json.npz';src_input=REVIEW/'shield_input_L25.bin'
    assert sha(src_input)=='e66a9bf7ccfed4532ff6b77f7db86019d340545005f39b207a8882b0f94be818'
    ids_spec=m['arrays']['silu_group_ids'];groups_spec=m['arrays']['silu_groups']
    def array(spec):
        path=mp.parent/spec['file'];assert sha(path)==spec['sha256'];assert spec['dtype']=='int64'
        return np.fromfile(path,dtype='<i8').reshape(spec['shape'])
    ids=array(ids_spec);groups=array(groups_spec);assert groups.shape==(4,2) and any(tuple(g)==(0,-8) for g in groups)
    c=m['constants'];delta=groups[ids,1]-c['silu_member'][1]
    exponent=24-c['sh_h']+delta;assert np.all((exponent>=0)&(exponent<=16))
    names={'x':'input','u':'up'};rows=[]
    with np.load(reference,allow_pickle=False) as data:
        x=np.fromfile(src_input,dtype='<i2').reshape(256,3072)[:128]
        assert np.array_equal(x,data['x'][:128])
        OUT.mkdir();x.astype('<i2').tofile(OUT/'input.i16')
        for old_name in data.files:
            value=data[old_name]
            if old_name in ['s','p']:
                assert value.shape==(32,256,256);value=value[:,:128,:128]
            else:
                assert value.shape[0]==256;value=value[:128]
            name=names.get(old_name,old_name)
            if old_name=='a_raw':name='a_scaled';value=value*np.left_shift(np.int64(1),exponent)
            value=np.asarray(value,dtype='<i8')
            rows.append({'site':name,'shape':list(value.shape),'words':value.size,
                'sha256':hashlib.sha256(value.tobytes()).hexdigest(),'range':[int(value.min()),int(value.max())]})
    assert len(rows)==19 and len({r['site'] for r in rows})==19
    coarse=ids==next(i for i,g in enumerate(groups) if tuple(g)==(0,-8))
    with np.load(reference,allow_pickle=False) as data:coarse_below=int(np.count_nonzero(data['gate'][:128,coarse]<-1024))
    report={'utc':datetime.now(timezone.utc).isoformat(),'scope':'Prepared T128 arithmetic oracle prefix from reviewer-validated actual ShieldstralL25/T256 residual reference. Causal prefix property, same weights/calibration and exact first128RoPE rows. No T256 proof, no native R14 L25 result yet, no app private item data or privacy acceptance.',
        'prefix_argument':'Norm, FFN and residual are token-local; causal attention for t<128 only consumes keys/values j<=t<128. Public RoPE rows/weights/calibration match exactly. Thus every listed T128 trace equals the selected causal prefix of the accepted T256 arithmetic oracle.',
        'layer':25,'tokens':128,'groups':groups.tolist(),'coarse_member_channels':int(np.count_nonzero(coarse)),
        'coarse_member_gate_words_below_minus1024':coarse_below,'trace_sites':rows,
        'input_sha256':sha(OUT/'input.i16'),'input_bytes':(OUT/'input.i16').stat().st_size,
        'source_sha256':{str(path.relative_to(ROOT)):sha(path) for path in [p,old,mp,op,compare,reference,src_input,Path(__file__)]}}
    (OUT/'ORACLE.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'tokens':128,'layer':25,'sites':19,'groups':4,'coarse_words_below_minus1024':coarse_below,'native_R14_result':'pending'}))
if __name__=='__main__':main()
