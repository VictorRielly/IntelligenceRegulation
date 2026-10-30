"""R12b table contract: independent full-reference match before publication.

The completed dg base and S2 evaluator remain untouched. A separate profile
copy binds BOS/final norms and the proposed classifier IDs/scale. Native R-C2
must register that margin policy; these candidate tables alone are not a proof.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import numpy as np
import calibration_port as P
from build_token_io import embedding_rows, quantized_rows, final_norm_maxima, norm_parameters, write_array
from collect_stats import sha, atomic_json, widened
from shieldstral_geometry import D, LAYERS, VOCAB, MODEL, Rotation, tied_source

HERE = Path(__file__).resolve().parent
BASE = HERE / 'dg_base_t256'
REFERENCE = HERE.parent / 'zk60_1b_native_20261017/r12b/reference_tables.json'
OUT = HERE / 'dg_r12b_t256'


def main():
    if OUT.exists():
        raise ValueError('output already exists; verify or use a new version')
    reference = json.loads(REFERENCE.read_text())
    profile = json.loads((BASE / 'profile.json').read_text())
    completed = json.loads((BASE / 'layers.complete.json').read_text())
    if completed['layers'] != LAYERS or sha(BASE / 'profile.json') != completed['profile_sha256']:
        raise ValueError('base export is not complete')
    for name, digest in json.loads((BASE / 'build.json').read_text())['source'].items():
        if sha(HERE / name) != digest:
            raise ValueError('base source changed: ' + name)
    R = Rotation()
    if profile['metadata_out_of_proof']['rotation'] != R.metadata() or sha(BASE / 'rotation_sign.bin') != R.metadata()['sign_sha256']:
        raise ValueError('rotation changed')
    stage = HERE / 'dg_r12b_t256.building'
    stage.mkdir(exist_ok=False)
    tables = stage / 'token_io'
    tables.mkdir()
    sin = profile['metadata_out_of_proof']['residual_scales_in'][0]
    sout = profile['metadata_out_of_proof']['residual_scales_out'][-1]
    maxima = final_norm_maxima(HERE / 'stats_t256')
    headnorm = norm_parameters(maxima, sout, profile['profile_constants']['norm_tn'])
    classnorm = norm_parameters(maxima, sout, 10)
    fn = {k: classnorm[k] for k in ('g0', 'tn', 'ceps')}
    fn['cn'] = classnorm['cn_refusal_free']
    hn = {k: headnorm[k] for k in ('g0', 'tn', 'ceps')}
    hn['cn'] = headnorm['cn_calibrated']
    if fn['ceps'] != hn['ceps'] or fn['ceps'] != profile['profile_constants']['norm_ceps']:
        raise ValueError('final norm epsilon differs')
    prep = HERE.parent / 'zk60_shieldstral_prep_20261021'
    sys.path.insert(0, str(prep / 'tools'))
    import shieldstral_common as C
    C.setup_paths()
    yes, no, _, _ = C.verdict_token_ids()
    bos = C.hf_tokenizer().token_to_id('<s>')
    if bos != 1:
        raise ValueError('BOS differs from R12b contract')
    ck = P.tc.open_checkpoint()
    raw = ck.refs['model.embed_tokens.weight'].bf16_rows()
    norm = P.tc.tensor_f32(ck.refs['model.norm.weight']).astype(np.float64)
    scales = np.zeros(VOCAB)
    with (tables / 'embedding_int16.bin').open('wb') as ef, (tables / 'head_int8_perrow.bin').open('wb') as hf:
        for first in range(0, VOCAB, 512):
            rows = raw[first:first+512]
            ef.write(embedding_rows(rows, R, sin).tobytes())
            words, s = quantized_rows(R.fwd(widened(rows).astype(np.float64) * norm), 127)
            hf.write(words.astype('i1').tobytes())
            scales[first:first+len(s)] = s
        for stream in (ef, hf):
            stream.flush()
            os.fsync(stream.fileno())
    mult = np.maximum(1, np.floor(4096 * scales / scales.max() + .5)).astype('<i8')
    (tables / 'head_mult12.bin').write_bytes(mult.tobytes())
    # The independent reference uses IDs 1/2. Product yes/no IDs are different;
    # validate the same quantizer on the reference pair before using them.
    pair = widened(raw[np.array([reference['yes'], reference['no']])]).astype(np.float64)
    difference = R.fwd((pair[0]-pair[1]) * norm)
    refwords = np.floor(difference / reference['margin_scale'] + .5)
    if not np.isfinite(refwords).all() or np.any(np.abs(refwords) > 32767):
        raise ValueError('reference margin would clip')
    actual = {'embedding_sha256': sha(tables / 'embedding_int16.bin'),
              'head_sha256': sha(tables / 'head_int8_perrow.bin'),
              'multipliers_sha256': sha(tables / 'head_mult12.bin'),
              'margin_sha256': hashlib.sha256(refwords.astype('<i2').tobytes()).hexdigest()}
    if any(value != reference[name] for name,value in actual.items()):
        raise ValueError('full-table quantizer differs from independent R12b reference')
    atomic_json(stage / 'reference_crosscheck.json', {'status': 'PASS', 'reference_sha256': sha(REFERENCE),
                'actual': actual, 'rows': VOCAB, 'width': D, 'reference_ids': [reference['yes'], reference['no']]})
    pair = widened(raw[np.array([yes, no])]).astype(np.float64)
    margin, scale = quantized_rows(R.fwd((pair[0]-pair[1]) * norm), 32767)
    if not float(scale) > 0:
        raise ValueError('degenerate classifier margin')
    ck.close()
    # Publish no table manifest until the full independent comparison passed.
    margin_meta = write_array(tables / 'margin_int16.bin', margin, '<i2')
    scales_meta = write_array(tables / 'head_row_scales_f64.bin', scales, '<f8')
    write_array(tables / 'calib_final_xhat_rot_absmax.bin', maxima, '<f8')
    profile['token_io_parameters'] = {'bos': bos, 'classifier_final_norm': fn, 'head_final_norm': hn}
    profile['classifier_margin_parameters'] = {'yes_id': yes, 'no_id': no, 'public_scale': float(scale), 'threshold_c': 0,
        'status': 'candidate profile values; native R-C2 policy registration and fidelity required'}
    profile['token_io_derivation'] = {'source_sha256': sha(__file__), 'base_profile_sha256': completed['profile_sha256'],
        'quantizer_source_sha256': sha(HERE / 'build_token_io.py'), 'reference_sha256': sha(REFERENCE)}
    scope = 'candidate tied public tables with independent reference match; native loader, policy registration, fidelity and privacy acceptance still required'
    def meta(name, dtype, shape):
        p = tables / name
        return {'file': name, 'dtype': dtype, 'shape': shape, 'bytes': p.stat().st_size, 'sha256': sha(p)}
    embedding = meta('embedding_int16.bin', 'int16', [VOCAB,D])
    embedding['source_tensor'] = tied_source()
    atomic_json(tables / 'token_io.json', {'schema': 'zk60-trained-profile-export/1', 'kind': 'token_io', 'model': MODEL,
        'T': profile['T'], 'bos': bos, 'embedding_table': embedding, 's_x_in_layer0': sin, 's_x_out_layer25': sout,
        'rotation': R.metadata(), 'rms_norm_eps': P.tc.GEO.eps, 'scope': scope})
    atomic_json(tables / 'head_manifest.json', {'kind': 'D25 per-row int8 plus 12-bit multipliers',
        'source_tensor': tied_source(), 'V': VOCAB, 'd': D, 'bos': bos,
        'head_int8_perrow.bin': meta('head_int8_perrow.bin', 'int8', [VOCAB,D]),
        'head_mult12.bin': meta('head_mult12.bin', 'int64', [VOCAB]), 'row_scales': scales_meta,
        'final_norm': {**headnorm, 'cn': hn['cn']}, 'scope': scope})
    atomic_json(tables / 'classifier.json', {'schema': 'zk60-classifier-tables/1', 'bos': bos, 'final_norm': fn,
        'margin_vector': {**margin_meta, 'd': D, 'scale': float(scale), 'source_tensor': tied_source()},
        'yes_id': yes, 'no_id': no, 'threshold_c': 0, 'tau': .5,
        'real_margin_scale': float(P.b3.norm_K(fn['cn'], fn['tn']) / fn['g0'] * scale),
        'final_norm_candidates': classnorm, 'choice': 'refusal-free pending A1 fidelity comparison', 'scope': scope})
    # Use new profile/marker in a separate export; shared immutable weight bytes
    # are hardlinks only. The original evidence and profile hashes stay intact.
    for member in BASE.iterdir():
        if member.name in ('profile.json', 'layers.complete.json'):
            continue
        if member.is_dir():
            shutil.copytree(member, stage / member.name, copy_function=os.link)
        else:
            os.link(member, stage / member.name)
    atomic_json(stage / 'profile.json', profile)
    atomic_json(stage / 'layers.complete.json', {'layers': LAYERS, 'profile_sha256': sha(stage / 'profile.json')})
    atomic_json(tables / 'complete.json', {'files': {p.name: sha(p) for p in sorted(tables.iterdir()) if p.is_file()},
        'profile_sha256': sha(stage / 'profile.json'), 'reference_crosscheck_sha256': sha(stage / 'reference_crosscheck.json'),
        'scope': scope, 'quantization_refusals': 0})
    os.rename(stage, OUT)
    print(json.dumps({'out': str(OUT), 'reference_match': True, 'yes': yes, 'no': no,
                      'margin_scale': float(scale), 'profile_sha256': sha(OUT / 'profile.json')}), flush=True)


if __name__ == '__main__':
    main()
