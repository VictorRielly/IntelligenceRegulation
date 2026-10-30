"""Derive the full native T128 public candidate from audited T256 arrays.

No weight or calibration changes: only context metadata and exact YaRN rows.
Copies are independent files so this lane cannot mutate Sol's retained export.
"""
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import resource
import shutil
import time
import numpy as np
from shieldstral_geometry import rope_tables

HERE=Path(__file__).resolve().parent
OUT=HERE/'native_low_h24_t128'

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1<<20),b''):h.update(block)
    return h.hexdigest()

def read(path):return json.loads(path.read_text())
def save(path,obj):
    temporary=path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(json.dumps(obj,indent=2,sort_keys=True)+'\n');temporary.replace(path)

def copy(source,target,digest):
    assert source.is_file() and not source.is_symlink() and sha(source)==digest, str(source)
    if target.exists():assert sha(target)==digest,str(target)
    else:
        temporary=target.with_suffix(target.suffix+'.tmp');shutil.copyfile(source,temporary)
        assert sha(temporary)==digest;temporary.replace(target)

def main():
    started=time.monotonic();audit=read(HERE/'native_export_equivalence.json');source=Path(audit['export'])
    assert audit['all_payload_bytes_verified'] and len(audit['layers'])==26
    assert sha(source/'profile.json')==audit['profile_sha256']
    original=read(source/'profile.json');profile=json.loads(json.dumps(original))
    provenance={'source_profile_sha256':audit['profile_sha256'],'audit_sha256':sha(HERE/'native_export_equivalence.json'),
                'builder_sha256':sha(Path(__file__)),'change':'T256 to T128, first128 YaRN rows, no requantization or calibration change'}
    OUT.mkdir(exist_ok=True)
    if (OUT/'build.json').exists():assert read(OUT/'build.json')==provenance,'resume provenance changed'
    else:save(OUT/'build.json',provenance)
    profile.update(T=128,geometry='shieldstral-3b-t128',variant='shieldstral-s2-fixed-low-h24-t128-v2',layers=[],
                   scope='full26 public native S2 candidate; full benchmark, full-stack proof and review remain separate')
    profile['calibration_tool']={'path':Path(__file__).name,'sha256':provenance['builder_sha256']}
    profile['context_derivation']=provenance
    layer_rows=[]
    for index,row in enumerate(audit['layers']):
        assert row['layer']==index
        src=source/f'layer_{index:02d}';dst=OUT/src.name;dst.mkdir(exist_ok=True)
        assert sha(src/'manifest.json')==row['manifest_sha256'];manifest=read(src/'manifest.json')
        manifest['variant']=profile['variant'];changed=[]
        for name,spec in manifest['arrays'].items():
            assert spec['sha256']==row['arrays'][name]
            if name in ('rope_cos','rope_sin'):
                p=src/spec['file'];assert sha(p)==spec['sha256']
                full=np.fromfile(p,dtype='<i8').reshape(spec['shape']);part=full[:128].copy()
                expected=rope_tables(128,manifest['constants']['f_ro'])[0 if name=='rope_cos' else 1]
                assert np.array_equal(part,expected),'context RoPE differs from pinned YaRN'
                data=part.astype('<i8').tobytes();target=dst/spec['file']
                if target.exists():assert target.read_bytes()==data
                else:target.write_bytes(data)
                spec.update(shape=list(part.shape),sha256=hashlib.sha256(data).hexdigest());changed.append(name)
            else:copy(src/spec['file'],dst/spec['file'],spec['sha256'])
        assert set(changed)=={'rope_cos','rope_sin'}
        manifest['tables']['rope']['t_max']=128
        manifest['tables']['rope'].pop('spec_digest',None)
        save(dst/'manifest.json',manifest)
        profile['layers'].append({'layer':index,'dir':dst.name,'manifest_sha256':sha(dst/'manifest.json')})
        layer_rows.append({'layer':index,'source_manifest_sha256':row['manifest_sha256'],
                           'manifest_sha256':sha(dst/'manifest.json'),'arrays':manifest['arrays'],
                           'changed_payloads':changed,'all_base_constants_preserved':True})
        print(json.dumps({'layer':index,'context':128,'weights_and_calibration_unchanged':True}),flush=True)
    token=OUT/'token_io';token.mkdir(exist_ok=True);token_hashes={}
    for name,digest in audit['token_io'].items():
        if name=='token_io.json':
            assert sha(source/'token_io'/name)==digest
            meta=read(source/'token_io'/name);assert meta['T']==256;meta['T']=128;save(token/name,meta)
        else:copy(source/'token_io'/name,token/name,digest)
        token_hashes[name]=sha(token/name)
    copy(source/'rotation_sign.bin',OUT/'rotation_sign.bin',audit['rotation_sha256'])
    save(OUT/'profile.json',profile)
    save(token/'complete.json',{'profile_sha256':sha(OUT/'profile.json'),'files':token_hashes,
                              'scope':'unchanged public tied arrays, T128 metadata; no native classifier registration'})
    result={'schema':'zk60-native-context-derivation/1','at':datetime.now(timezone.utc).isoformat(),
        'source':provenance,'profile_sha256':sha(OUT/'profile.json'),'layers':layer_rows,
        'token_io':token_hashes,'rotation_sha256':audit['rotation_sha256'],'context_tokens':128,
        'all_payloads_hash_verified':True,'weights_and_calibration_unchanged':True,'native_load_pending':True,
        'scope':'full26 public native-format candidate; not a full26 proof, fidelity or privacy acceptance',
        'elapsed_seconds':time.monotonic()-started,'peak_rss_gib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1024**2,
        'measurement_note':'n=1 shared host'}
    save(OUT/'complete.json',result)
    print(json.dumps({k:result[k] for k in ('profile_sha256','elapsed_seconds','peak_rss_gib','native_load_pending')}),flush=True)

if __name__=='__main__':main()
