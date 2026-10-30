"""Load the explicitly selected, hash-pinned layer25 numerical candidate."""
import json
from pathlib import Path
import numpy as np
import calibration_port as P
from collect_stats import sha
from accuracy_stack import group_tables

HERE = Path(__file__).resolve().parent


def candidate_pin(directory):
    directory = Path(directory)
    meta = json.loads((directory / 'complete.json').read_text())
    if sha(HERE / 'fix_layer25.py') != meta['source_sha256']:
        raise ValueError('candidate construction source changed')
    if sha(directory / 'candidate.npz') != meta['candidate_sha256']:
        raise ValueError('candidate arrays changed')
    return {'path': str(directory.resolve()), 'complete_sha256': sha(directory / 'complete.json'),
            'loader_sha256': sha(__file__)}


def apply_candidate(model, directory):
    directory = Path(directory)
    candidate_pin(directory)
    meta = json.loads((directory / 'complete.json').read_text())
    with np.load(directory / 'candidate.npz', allow_pickle=False) as arrays:
        words = arrays['wu_t']
        mult = arrays['mult_u']
        ej = arrays['group_input_exponents']
        eo = arrays['group_output_exponents']
        if words.shape != model.w['wu_t'].shape or mult.shape != model.mult['u'][0].shape:
            raise ValueError('candidate up dimensions differ')
        if words.dtype != np.dtype('int8') or np.any(words == -128) or np.any(mult < 1) or np.any(mult > 16):
            raise ValueError('candidate up class differs')
        members, ids, tables = group_tables(ej, eo)
        if [list(m) for m in members] != meta['group_members'] or not np.array_equal(ids, arrays['group_ids']) or not np.array_equal(tables, arrays['group_tables']):
            raise ValueError('candidate group tables differ')
    before = model.c
    after = meta['constants']
    if any(before[k] != after.get(k) for k in before if k != 'sh_h') or after['sh_h'] != before['sh_h'] - 1:
        raise ValueError('unexpected layer25 constant change')
    model.w['wu_t'] = words
    model.int['u'] = P.fl.Mat(words)
    model.mult['u'] = (mult.astype(np.float64), 4)
    model.c = dict(after)
    model.gate_pc = (ej, eo, np.empty((0, 0)), False)
    return model
