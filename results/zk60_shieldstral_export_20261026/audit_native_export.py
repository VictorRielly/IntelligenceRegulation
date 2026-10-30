"""Independently reconcile Sol's native-v2 export with the numerical candidate.

One NPZ member is loaded at a time; native payloads are streamed. This is an
artifact-equivalence audit, not proof, fidelity, or independent security review.
"""
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import resource
import time
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
NATIVE=ROOT/'results/zk60_1b_native_20261017/r13'
EXPORT=NATIVE/'shieldstral-export-v2'
SOURCE=HERE/'s2_evaluation_t256'
BASE=HERE/'dg_r12b_t256'
FIX=HERE/'layer25_fix_candidate'
OUT=HERE/'native_export_equivalence.json'

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()

def read(path):return json.loads(path.read_text())
def require(value,message):
    if not value:raise ValueError(message)

def file_at(directory,name):
    require(isinstance(name,str) and name==Path(name).name,'nonlocal payload name')
    p=directory/name
    require(p.is_file() and not p.is_symlink(),'missing or symbolic payload: '+str(p))
    return p

def main():
    start=time.monotonic()
    # The same pinned numerical sources used by the running fidelity evaluator.
    from evaluation_export import EvaluationExport
    from amended_evaluator import candidate_pin
    model=EvaluationExport(SOURCE);candidate=candidate_pin(FIX)
    original=read(BASE/'profile.json');profile=read(EXPORT/'profile.json')
    complete=read(SOURCE/'complete.json');fixmeta=read(FIX/'complete.json')
    adapter=read(EXPORT/'ADAPTER_COMPLETE.json')
    require(adapter['profile_sha256']==sha(EXPORT/'profile.json') and adapter['layers']==26,'native completion differs')
    require(adapter['adapter_sha256']==sha(NATIVE/'prepare_shieldstral_export_v2.py'),'converter pin changed')
    require(adapter['audit_sha256']==sha(HERE/'native_candidate_audit.json'),'candidate audit pin changed')
    require(profile['schema']=='zk60-trained-profile-export/2' and profile['accuracy_stack']=='low-h24-v1','wrong native stack')
    require(profile['T']==256 and profile['geometry']=='shieldstral-3b-t256','wrong native geometry')
    require(profile['sequences']==[] and len(profile['layers'])==26,'incomplete or private native profile')
    changed={'schema','accuracy_stack','variant','calibration_tool','sequences','layers','scope','profile_constants','variant_options','r13_adapter_provenance'}
    require(set(profile)==set(original)|{'accuracy_stack','r13_adapter_provenance'},'unexpected profile fields')
    for key,value in original.items():
        if key not in changed:require(profile[key]==value,'native profile differs: '+key)
    require(profile['profile_constants']=={**original['profile_constants'],'f_p':12},'base constants changed beyond FP12 declaration')
    require(profile['variant_options']=={**original['variant_options'],'f_p':12},'calibration options changed')
    prov=profile['r13_adapter_provenance']
    require(prov['base_profile_sha256']==sha(BASE/'profile.json') and prov['evaluation_export_sha256']==sha(SOURCE/'complete.json')
            and prov['layer25_candidate_sha256']==fixmeta['candidate_sha256'],'native provenance differs from evaluator')
    require(profile['calibration_tool']['sha256']==adapter['adapter_sha256'],'profile converter pin differs')
    rows=[];byte_count=0
    with np.load(FIX/'candidate.npz',allow_pickle=False) as fixed:
        for index,entry in enumerate(profile['layers']):
            require(entry['layer']==index and entry['dir']==f'layer_{index:02d}','layer order differs')
            source=SOURCE/entry['dir'];target=EXPORT/entry['dir']
            require(sha(source/'ready.json')==complete['layers_sha256'][index],'numerical ready pin differs')
            ready=read(source/'ready.json')
            for name,digest in ready['files'].items():require(sha(file_at(source,name))==digest,'numerical source changed')
            require(sha(target/'manifest.json')==entry['manifest_sha256'],'native layer manifest changed')
            native=read(target/'manifest.json');meta=read(source/'arithmetic.json')
            constants=fixmeta['constants'] if index==25 else meta['constants']
            expected={k:constants[k] for k in original['profile_constants']};expected['f_p']=12
            require(native['constants']==expected,'native base shifts or constants differ')
            mapping={k:('w__'+k,'int8') for k in ('wq','wk','wv','wo','gamma_a','gamma_m','wg_t','wu_t','wd_t')}
            mapping.update({k:('w__'+k,'int64') for k in ('exp','rope_cos','rope_sin')})
            mapping.update({'m_'+site:('extra__mult_'+site,'int64') for site in 'qkvogud'})
            mapping.update(silu_group_ids=('extra__group_ids','int64'),act=('extra__group_tables','int16'),
                           silu_groups=(None,'int64'))
            require(set(native['arrays'])==set(mapping),'native payload set differs')
            require({p.name for p in target.iterdir()}=={'manifest.json','adapter-ready.json'}|
                    {spec['file'] for spec in native['arrays'].values()},'unexpected native layer files')
            hashes={}
            with np.load(source/'arrays.npz',allow_pickle=False) as arrays:
                for name,(key,dtype) in mapping.items():
                    if name=='silu_groups':value=np.asarray(fixmeta['group_members'] if index==25 else meta['group_members'],dtype='<i8')
                    elif index==25 and name in ('wu_t','m_u','silu_group_ids','act'):
                        value=fixed[{'wu_t':'wu_t','m_u':'mult_u','silu_group_ids':'group_ids','act':'group_tables'}[name]]
                    else:value=arrays[key]
                    target_dtype=np.dtype(dtype).newbyteorder('<')
                    require(np.issubdtype(value.dtype,np.integer),'noninteger numerical payload')
                    bounds=np.iinfo(target_dtype)
                    require(value.min()>=bounds.min and value.max()<=bounds.max,'lossy dtype conversion')
                    value=np.asarray(value,dtype=target_dtype,order='C')
                    spec=native['arrays'][name]
                    require(spec['shape']==list(value.shape) and spec['dtype']==dtype,'native payload geometry differs')
                    expected_digest=hashlib.sha256(memoryview(value).cast('B')).hexdigest()
                    payload=file_at(target,spec['file'])
                    require(payload.stat().st_size==value.nbytes and spec['sha256']==expected_digest==sha(payload),
                            f'native payload changed: layer{index}/{name}')
                    hashes[name]=expected_digest;byte_count+=value.nbytes
                    del value
            rows.append({'layer':index,'arrays':hashes,'manifest_sha256':entry['manifest_sha256'],
                         'source_archive_sha256':ready['files']['arrays.npz'],'constants_match':True})
            print(json.dumps({'layer':index,'arrays_matched':len(hashes)}),flush=True)
    token_complete=read(BASE/'token_io/complete.json');tokens={}
    names=['embedding_int16.bin','head_int8_perrow.bin','head_mult12.bin','head_row_scales_f64.bin',
           'margin_int16.bin','token_io.json','head_manifest.json','classifier.json']
    require({p.name for p in (EXPORT/'token_io').iterdir()}==set(names),'unexpected public token files')
    require(token_complete['profile_sha256']==sha(BASE/'profile.json'),'token table authority differs')
    for name in names:
        digest=token_complete['files'][name]
        require(sha(file_at(BASE/'token_io',name))==digest==sha(file_at(EXPORT/'token_io',name)),'tied public table changed')
        tokens[name]=digest
    rotation=profile['metadata_out_of_proof']['rotation']['sign_sha256']
    require(sha(file_at(EXPORT,'rotation_sign.bin'))==rotation==sha(BASE/'rotation_sign.bin'),'rotation changed')
    expected_top={'profile.json','ADAPTER_COMPLETE.json','rotation_sign.bin','token_io'}|{f'layer_{i:02d}' for i in range(26)}
    require({p.name for p in EXPORT.iterdir()}==expected_top,'unexpected private or unlisted export payload')
    report=read(NATIVE/'SOL_REPORT_20261029.json');guard=read(NATIVE/'release-2-actual-import.guard.json')
    require(guard['exit']==guard['child_rc']==0 and guard['guard_killed'] is None,'native import gate failed')
    native_log=(NATIVE/'release-2-actual-import.log').read_text()
    require(all(f'R13_ACTUAL_IMPORT layer={i} ' in native_log for i in range(26)) and
            '1 passed; 0 failed' in native_log,'native full import evidence incomplete')
    result={'schema':'zk60-native-export-equivalence/1','at':datetime.now(timezone.utc).isoformat(),
        'scope':'COUNTED/MEASURED exact public-array equivalence to numerical candidate, not proof/fidelity/privacy acceptance',
        'export':str(EXPORT),'profile_sha256':sha(EXPORT/'profile.json'),'context_tokens':256,
        'layers':rows,'array_count':sum(len(r['arrays']) for r in rows),'layer_payload_bytes':byte_count,
        'token_io':tokens,'rotation_sha256':rotation,'evaluation_export_sha256':sha(SOURCE/'complete.json'),
        'layer25_candidate':candidate,'all_payload_bytes_verified':True,'public_only':True,
        'native_release':{'source_tree_sha256':report['source_tree_sha256'],'status':report['status'],
            'import_guard_sha256':sha(NATIVE/'release-2-actual-import.guard.json'),
            'import_log_sha256':sha(NATIVE/'release-2-actual-import.log'),'import_layers':26,
            'actual_proof_scope':report['verification_scope']['actual_proofs']},
        'tool_sha256':sha(Path(__file__)),'elapsed_seconds':time.monotonic()-start,
        'peak_rss_gib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1024**2,
        'measurement_note':'n=1 shared host; streaming audit, no proof throughput claim'}
    temporary=OUT.with_suffix('.tmp');temporary.write_text(json.dumps(result,indent=2)+'\n');temporary.replace(OUT)
    print(json.dumps({k:result[k] for k in ('profile_sha256','array_count','all_payload_bytes_verified','elapsed_seconds','peak_rss_gib')}),flush=True)

if __name__=='__main__':main()
