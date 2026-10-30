"""Lossless, resumable public-array adapter for Astra's fixed S2 candidate.

No quantization or sequence data: fp12 is made explicit in the v2 metadata;
the audited integer weights, multipliers, tables and base shifts are copied.
The native loader independently validates arithmetic, tables and source pins.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import numpy as np

HERE = Path(__file__).resolve().parent
ASTRA = HERE.parent.parent / 'zk60_shieldstral_export_20261026'
SOURCE = ASTRA / 's2_evaluation_t256'
BASE = ASTRA / 'dg_r12b_t256'
OUT = HERE / 'shieldstral-export-v2'
AUDIT_SHA = 'a60edbc04fdc4ea1338a44698a8cf9628906fb9656042281ee77a37319200950'
BASE_SHA = '212244e40393a34ceb16943694384c1950b933e4f8f2e7a02634e2d5983f260e'

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''): h.update(b)
    return h.hexdigest()

def read(path): return json.loads(path.read_text())

def write_json(path, data):
    payload = (json.dumps(data, indent=2, sort_keys=True) + '\n').encode()
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_bytes(payload)
    temporary.replace(path)

def copy_checked(src, dst, digest):
    assert src.is_file() and not src.is_symlink() and sha(src) == digest, str(src)
    if dst.exists(): assert sha(dst) == digest, str(dst)
    else:
        temporary = dst.with_suffix(dst.suffix + '.tmp')
        shutil.copyfile(src, temporary)
        assert sha(temporary) == digest, str(temporary)
        temporary.replace(dst)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--limit-layers', type=int, default=26)
    args = parser.parse_args()
    assert 1 <= args.limit_layers <= 26
    assert sha(ASTRA / 'native_candidate_audit.json') == AUDIT_SHA
    assert sha(BASE / 'profile.json') == BASE_SHA
    audit = read(ASTRA / 'native_candidate_audit.json')
    assert sha(SOURCE / 'complete.json') == audit['evaluation_export_sha256']
    complete = read(SOURCE / 'complete.json')
    fixdir = ASTRA / 'layer25_fix_candidate'
    assert sha(fixdir / 'complete.json') == audit['candidate']['complete_sha256']
    assert sha(fixdir / 'candidate.npz') == read(fixdir / 'complete.json')['candidate_sha256']
    assert complete['layers'] == len(audit['layers']) == 26
    OUT.mkdir(exist_ok=True)
    profile = read(BASE / 'profile.json')
    profile.update(schema='zk60-trained-profile-export/2', accuracy_stack='low-h24-v1',
                   variant='shieldstral-s2-fixed-low-h24-v2', sequences=[], layers=[],
                   scope='actual public S2 integer candidate; native proof/fidelity/privacy acceptance pending')
    profile['profile_constants']['f_p'] = 12
    profile['variant_options']['f_p'] = 12
    profile['calibration_tool'] = {'path': str(Path(__file__).relative_to(HERE)), 'sha256': sha(Path(__file__))}
    profile['r13_adapter_provenance'] = {
        'audit_sha256': AUDIT_SHA, 'base_profile_sha256': BASE_SHA,
        'evaluation_export_sha256': sha(SOURCE / 'complete.json'),
        'layer25_candidate_sha256': sha(fixdir / 'candidate.npz'),
        'normalization': 'base f_p9 -> explicit effective f_p12; all base shifts and integer arrays unchanged; layer25 uses fixed up matrix/multiplier and sh_h15',
    }
    with np.load(fixdir / 'candidate.npz', allow_pickle=False) as fix:
        for row in audit['layers']:
            i = row['layer']; source = SOURCE / f'layer_{i:02d}'; target = OUT / source.name
            assert sha(source / 'ready.json') == complete['layers_sha256'][i]
            ready = read(source / 'ready.json')
            target.mkdir(exist_ok=True)
            marker = target / 'adapter-ready.json'
            if marker.exists():
                prior = read(marker)
                assert prior['audit_sha256'] == AUDIT_SHA and prior['source_archive_sha256'] == ready['files']['arrays.npz']
                assert sha(target / 'manifest.json') == prior['manifest_sha256']
                manifest = read(target / 'manifest.json')
                for spec in manifest['arrays'].values(): assert sha(target / spec['file']) == spec['sha256']
            else:
                for name, digest in ready['files'].items(): assert sha(source / name) == digest
                manifest = read(BASE / source.name / 'manifest.json')
                manifest['schema'] = profile['schema']; manifest['variant'] = profile['variant']
                manifest['constants'] = {key: row['constants'][key] for key in manifest['constants']}
                manifest['constants']['f_p'] = 12
                arrays = {}; manifest['arrays'] = arrays
                def array(name, value, dtype):
                    a = np.asarray(value, dtype=dtype, order='C')
                    path = target / (name + '.bin')
                    with path.open('wb') as f: a.tofile(f)
                    arrays[name] = {'file': path.name, 'dtype': {'i1':'int8','<i8':'int64','<i2':'int16'}[dtype],
                                    'shape': list(a.shape), 'sha256': sha(path)}
                with np.load(source / 'arrays.npz', allow_pickle=False) as data:
                    for key in ['wq','wk','wv','wo','gamma_a','gamma_m','wg_t','wu_t','wd_t']:
                        value = fix['wu_t'] if i == 25 and key == 'wu_t' else data['w__' + key]
                        assert value.dtype == np.dtype('int8') and not np.any(value == -128)
                        array(key, value, 'i1')
                    for key in ['exp','rope_cos','rope_sin']: array(key, data['w__' + key], '<i8')
                    for site in 'qkvogud':
                        value = fix['mult_u'] if i == 25 and site == 'u' else data['extra__mult_' + site]
                        array('m_' + site, value, '<i8')
                    get = (lambda key: fix[key]) if i == 25 else (lambda key: data['extra__' + key])
                    array('silu_group_ids', get('group_ids'), '<i8')
                    array('silu_groups', row['group_members'], '<i8')
                    array('act', get('group_tables'), '<i2')
                manifest['tables']['act'] = {'generator': 'R13 registry int12 input, raw signed16 output, per public group',
                                            'group_members': row['group_members'], 'sha256': arrays['act']['sha256']}
                write_json(target / 'manifest.json', manifest)
                write_json(marker, {'audit_sha256': AUDIT_SHA, 'source_archive_sha256': ready['files']['arrays.npz'],
                                    'manifest_sha256': sha(target / 'manifest.json')})
                print(f'converted layer {i:02d}', flush=True)
            profile['layers'].append({'layer': i, 'dir': target.name, 'manifest_sha256': sha(target / 'manifest.json')})
            if len(profile['layers']) >= args.limit_layers: break
    if len(profile['layers']) != 26:
        print('bounded partial export; no profile.json published', flush=True); return
    td = OUT / 'token_io'; td.mkdir(exist_ok=True)
    token_complete = read(BASE / 'token_io/complete.json')
    # Public tables/manifests only; no calibration sequences or private IO.
    for name in ['embedding_int16.bin','head_int8_perrow.bin','head_mult12.bin',
                 'head_row_scales_f64.bin','margin_int16.bin','token_io.json','head_manifest.json','classifier.json']:
        copy_checked(BASE / 'token_io' / name, td / name, token_complete['files'][name])
    copy_checked(BASE / 'rotation_sign.bin', OUT / 'rotation_sign.bin', profile['metadata_out_of_proof']['rotation']['sign_sha256'])
    write_json(OUT / 'profile.json', profile)
    write_json(OUT / 'ADAPTER_COMPLETE.json', {'profile_sha256': sha(OUT / 'profile.json'), 'layers': 26,
               'adapter_sha256': sha(Path(__file__)), 'audit_sha256': AUDIT_SHA,
               'scope': 'lossless public array conversion; native acceptance pending'})
    print(json.dumps(read(OUT / 'ADAPTER_COMPLETE.json')), flush=True)

if __name__ == '__main__': main()
