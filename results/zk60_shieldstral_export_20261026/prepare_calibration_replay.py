"""Expose all calibration rows to the exact-length, resumable integer runner.

Includes every padded T256 row used to set the bounds. This is not a held-out
benchmark. No document, prompt, policy or padded position is excluded.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
from collect_stats import atomic_json, sha

HERE = Path(__file__).resolve().parent


def main():
    source = HERE / 'calibration_t256'
    data = json.loads((source / 'input.json').read_text())
    ids = np.load(source / 'ids.npy', allow_pickle=False)
    if ids.shape != (data['sequences'], data['T']) or hashlib.sha256(ids.astype('<i8').tobytes()).hexdigest() != data['ids_sha256']:
        raise ValueError('calibration input changed')
    out = HERE / 'calibration_replay_inputs'
    out.mkdir(exist_ok=False)
    np.save(out / 'ids.npy', ids.reshape(-1), allow_pickle=False)
    np.save(out / 'offsets.npy', np.arange(len(ids)+1, dtype=np.int64) * data['T'], allow_pickle=False)
    rows = [{**row, 'id': f'calibration-{i}', 'source_document_id': row['id'], 'dataset': 'calibration',
             'T': data['T'], 'weight': 1, 'content_tokens': row['length'], 'calibration_sequence': i}
            for i, row in enumerate(data['metadata'])]
    if len(rows) != len(ids):
        raise ValueError('calibration metadata count differs')
    atomic_json(out / 'input.json', {'schema': 'zk60-shieldstral-evaluation-input/1', 'rows': rows,
        'ids_sha256': sha(out / 'ids.npy'), 'offsets_sha256': sha(out / 'offsets.npy'),
        'calibration_input_sha256': sha(source / 'input.json'), 'source_sha256': sha(__file__),
        'scope': 'all 192 calibration sequences, all 49152 padded token rows; not held-out fidelity'})
    print(json.dumps({'sequences': len(rows), 'tokens': ids.size, 'output': str(out)}))


if __name__ == '__main__':
    main()
