"""Prover-private T128 sequence files from the pinned numerical integer model.

Run as one guarded CPU leaf with two BLAS threads. No native proof is created.
Every range refusal aborts; diagnostic clamps never become a completed input.
No input ids, activations, margins or private hashes are printed to stdout.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import time

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'apps/proven-media'))
from proven_media.shieldstral_text import CategoryTemplate, SPECIAL_TOKENS, VOCABULARY
from amended_evaluator import apply_candidate, candidate_pin
from collect_stats import sha
from evaluation_export import EvaluationExport
from evaluate_verdicts import row_diagnostics
import calibration_port as P
from shieldstral_geometry import D, LAYERS
from shieldstral_weights import read_exact
from signed_word_domain import S2RecPos

PROFILE_SHA256 = '2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0'
EVALUATION_SHA256 = '0818a06c74176921a406a1582231f82bee4247a4131f07438c3b955f5868197b'
EQUIVALENCE_SHA256 = '241f17aaf3468bb02866b5f99994542114db335314adb45ae3bebe79266280d6'
DERIVATION_SHA256 = '76ac4e698ba85f8c3e7bb19296b74f489923fc4876bd106e72193eda13364348'
POLICIES_SHA256 = 'b1cfcda9ea4f48ce3b95d871b81f77c6cd27f94daa85fc618ec8e54222b44314'
T = 128
NATIVE = HERE / 'native_low_h24_t128'


def private_read(path, limit):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077 or info.st_size > limit:
            raise ValueError('private request/input must be a bounded owner-only regular file')
        raw = stream.read(limit + 1)
        if len(raw) > limit:
            raise ValueError('private request/input grew beyond its bound')
        return raw


def private_write(path, raw):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())


def json_bytes(value):
    return (json.dumps(value, indent=2) + '\n').encode()


def policies():
    path = HERE / 'category_policy_candidates.json'
    if sha(path) != POLICIES_SHA256:
        raise ValueError('category templates changed')
    result = {}
    for key, row in json.loads(path.read_bytes())['policies'].items():
        if not key.startswith('mod_'):
            continue
        result[row['proposed_policy_id']] = CategoryTemplate(row['category'], row['proposed_policy_id'],
            tuple(row['prefix_ids']), tuple(row['suffix_ids']), T, 8, 8)
    if len(result) != 3:
        raise ValueError('exactly three moderate category templates are required')
    return result


def prepare_requests(requests):
    if not isinstance(requests, list) or not 1 <= len(requests) <= 24:
        raise ValueError('a request contains one to24 category chunks')
    templates = policies()
    prepared, names, identities = [], set(), set()
    for row in requests:
        if not isinstance(row, dict) or set(row) != {'name', 'policy_id', 'content_file', 'chunk_index'}:
            raise ValueError('invalid activation request')
        name = row['name']
        if type(name) is not str or not re.fullmatch('[A-Za-z0-9_-]{1,48}', name) or name in names:
            raise ValueError('activation names must be unique simple directory names')
        names.add(name)
        template = templates.get(row['policy_id'])
        if template is None:
            raise ValueError('activation policy is not a registered moderate category')
        raw = private_read(row['content_file'], 65536)
        try:
            fields = re.split(r'[,\s]+', raw.decode('ascii').strip())
            if not fields or any(not re.fullmatch('[0-9]{1,6}', field) for field in fields):
                raise ValueError()
            ids = tuple(int(field) for field in fields)
        except (ValueError, UnicodeDecodeError):
            raise ValueError('invalid private content encoding') from None
        if any(not SPECIAL_TOKENS <= i < VOCABULARY for i in ids):
            raise ValueError('content contains a forbidden token')
        plan = template.plan(len(ids))
        index = row['chunk_index']
        if type(index) is not int or not 0 <= index < len(plan):
            raise ValueError('invalid native category chunk index')
        identity = (row['policy_id'], ids, index)
        if identity in identities:
            raise ValueError('duplicate category activation request')
        identities.add(identity)
        prompt = template.prompt_ids(ids, plan[index])
        prepared.append({'name': name, 'policy_id': row['policy_id'], 'chunk': plan[index],
                         'content_total': len(ids), 'content_sha256': hashlib.sha256(raw).hexdigest(),
                         'prompt': prompt})
    return prepared


def checked_words(values, rec, expected_shape):
    if row_diagnostics(rec)['refused']:
        raise ValueError('integer range refusal; activation sequence is incomplete')
    values = np.asarray(values)
    if (values.shape != expected_shape or not np.isfinite(values).all()
            or not np.array_equal(values, np.floor(values))
            or np.any(values < -32768) or np.any(values > 32767)):
        raise ValueError('activation output is not an exact int16 array')
    return values.astype('<i2')


def write_sequences(request_file, output):
    started = time.monotonic()
    raw = private_read(request_file, 65536)
    prepared = prepare_requests(json.loads(raw))
    for path, pin in ((NATIVE / 'profile.json', PROFILE_SHA256),
                      (NATIVE / 'complete.json', DERIVATION_SHA256),
                      (HERE / 'native_export_equivalence.json', EQUIVALENCE_SHA256),
                      (HERE / 's2_evaluation_t256/complete.json', EVALUATION_SHA256)):
        if sha(path) != pin:
            raise ValueError('native/numerical artifact pin changed')
    audit = json.loads((HERE / 'native_export_equivalence.json').read_bytes())
    if candidate_pin(HERE / 'layer25_fix_candidate') != audit['layer25_candidate']:
        raise ValueError('layer25 correction changed')
    export = EvaluationExport(HERE / 's2_evaluation_t256')
    embedding = NATIVE / 'token_io/embedding_int16.bin'
    if sha(embedding) != audit['token_io']['embedding_int16.bin']:
        raise ValueError('tied embedding changed')
    output = Path(output)
    output.mkdir(mode=0o700, parents=False, exist_ok=False)
    private_write(output / 'request.json', raw)
    fd = os.open(embedding, os.O_RDONLY)
    try:
        for item in prepared:
            directory = output / item['name']
            directory.mkdir(mode=0o700)
            item['files'] = {}
            item['values'] = np.stack([np.frombuffer(read_exact(fd, D * 2, token * D * 2), dtype='<i2')
                                       for token in item.pop('prompt')])
    finally:
        os.close(fd)
    for layer in range(LAYERS):
        model = export.layer(layer, T)
        if layer == 25:
            model = apply_candidate(model, HERE / 'layer25_fix_candidate')
        for item in prepared:
            x = item['values']
            rec = S2RecPos(1)
            y = P.fl.rx_block(x.reshape(1, T, D).astype(np.float64), model, frozenset(P.fl.SITES), rec)[0]
            y = checked_words(y, rec, (T, D))
            for label, value in (('in', x), ('out', y)):
                name = f'x_{label}_L{layer:02d}.bin'
                data = value.astype('<i2', copy=False).tobytes()
                private_write(output / item['name'] / name, data)
                item['files'][name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
            item['values'] = y
        del model
        print(json.dumps({'layer': layer, 'category_chunks': len(prepared),
                          'seconds': round(time.monotonic() - started, 3)}), flush=True)
    rows = [{k: v for k, v in item.items() if k != 'values'} for item in prepared]
    result = {'schema': 'zk60-private-item-activations/1', 'profile_sha256': PROFILE_SHA256,
              'evaluation_export_sha256': EVALUATION_SHA256, 'writer_sha256': sha(__file__),
              'request_sha256': hashlib.sha256(raw).hexdigest(), 'dtype': 'int16-le',
              'shape': [T, D], 'layers': LAYERS, 'refusals': 0, 'items': rows,
              'seconds': time.monotonic() - started}
    private_write(output / 'complete.json', json_bytes(result))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--request', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    write_sequences(args.request, args.out)
