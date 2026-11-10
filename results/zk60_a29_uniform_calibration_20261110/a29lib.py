"""Lane A29 shared helpers: load the S2 numerical evaluator from ANY native-format
Shieldstral T128 export directory, reusing the export lane's frozen arithmetic.

Nothing here changes arithmetic. The model object is built exactly as
results/zk60_astra_20261026/mac_evaluation/portable_model.py builds it from the
pinned export (same LayerModel, MODS, c2 multiplier BITS, group SiLU tables and
matrix cache); the only difference is that the export directory is a parameter
and the evaluator constants are derived from the native manifest constants
(check_loader.py proves the derivation equal to the pinned evaluator's for all
26 layers of the current export). Run every script with `python -B` so that no
__pycache__ is written into the export lane's directories.
"""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path('/Users/victorrielly/IntelligenceRegulation')
EXPORT_LANE = ROOT / 'results/zk60_shieldstral_export_20261026'
ASTRA = ROOT / 'results/zk60_astra_20261026'
BASELINE = EXPORT_LANE / 'native_low_h24_t128'
BASELINE_PROFILE_SHA = '2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0'
L12_CANDIDATE = ASTRA / 'mac_score_native_candidate/native_t128'
CHECKPOINT_DIR = ASTRA / 'mac_export_recovery/checkpoint'
ART = Path('/Users/victorrielly/zk60-artifacts/a29-uniform-calibration')
HERE = Path(__file__).resolve().parent
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
PYTHON = Path('/Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python')

sys.path.insert(0, str(EXPORT_LANE))
import numpy as np  # noqa: E402
import calibration_port as P  # noqa: E402
from accuracy_stack import BITS, MODS, group_tables  # noqa: E402
from cached_integer import prepare  # noqa: E402

D = 3072
LAYERS = 26


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def record(path, value):
    path = Path(path)
    tmp = path.with_name(path.name + f'.{os.getpid()}.partial')
    with tmp.open('w') as f:
        json.dump(value, f, indent=1, sort_keys=True)
        f.write('\n')
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def require(ok, message):
    if not ok:
        raise ValueError(message)


def array(parent, spec):
    path = Path(parent) / spec['file']
    require(spec['file'] == Path(spec['file']).name, 'nonlocal array path')
    value = np.fromfile(path, dtype=np.dtype(spec['dtype']).newbyteorder('<'))
    require(value.size == int(np.prod(spec['shape'])), 'array size differs: ' + str(path))
    return value.reshape(spec['shape'])


def checked_array(parent, spec):
    require(sha(Path(parent) / spec['file']) == spec['sha256'], 'array digest differs: ' + spec['file'])
    return array(parent, spec)


def manifest(export, index):
    profile = read(Path(export) / 'profile.json')
    row = profile['layers'][index]
    require(row['layer'] == index and row['dir'] == f'layer_{index:02d}', 'layer order')
    parent = Path(export) / row['dir']
    require(sha(parent / 'manifest.json') == row['manifest_sha256'], 'manifest digest differs')
    return parent, read(parent / 'manifest.json')


def evaluator_constants(native_constants):
    """The S2 evaluator's constant dict from a native manifest's constants:
    the base f_p 9 (MODS fp12 applies the native 12), e_s / silu aliases and
    the norm window 31 that every layer of the S2 evaluator export carries."""
    c = dict(native_constants)
    c['f_p'] = 9
    c['e_s'] = c['exp_e_s']
    c['silu'] = list(c['silu_member'])
    c['wrho'] = 31
    return c


def decode_groups(groups, ids):
    require(groups.ndim == 2 and groups.shape[1] == 2, 'group member table')
    require(ids.shape == (9216,) and np.all(ids >= 0) and np.all(ids < len(groups)), 'group ids')
    values = groups[ids]
    return values[:, 0].copy(), values[:, 1].copy()


def load_model(export, index, verify=True, cache=True):
    """The S2 numerical evaluator of one layer of a native-format export."""
    parent, man = manifest(export, index)
    get = checked_array if verify else array
    weights = {name: get(parent, man['arrays'][name]) for name in
               ('wq', 'wk', 'wv', 'wo', 'gamma_a', 'gamma_m', 'wg_t', 'wu_t', 'wd_t', 'exp', 'rope_cos', 'rope_sin')}
    c = evaluator_constants(man['constants'])
    weights['act'] = P.b3.silu_generate(*c['silu'])  # base member table; unused with group tables
    weights['exp'] = weights['exp'].reshape(-1)
    model = P.fl.LayerModel({'w': weights, 'c': c}, 128, mods=MODS)
    model.mult = {site: (get(parent, man['arrays']['m_' + site]).astype(np.float64), bits)
                  for site, bits in BITS.items()}
    groups = get(parent, man['arrays']['silu_groups'])
    ids = get(parent, man['arrays']['silu_group_ids'])
    ein, eout = decode_groups(groups, ids)
    members, actual_ids, tables = group_tables(ein, eout)
    require(members == [tuple(map(int, g)) for g in groups] and np.array_equal(ids, actual_ids)
            and np.array_equal(tables, get(parent, man['arrays']['act'])), 'group reconstruction differs')
    model.gate_pc = (ein, eout, np.empty((0, 0)), False)
    return prepare(model) if cache else model


def gate_common_shift(c, groups, ids):
    """`accuracy_groups::group_folds_for`'s common gate denominator."""
    ein = int(c['silu_member'][0])
    ej = groups[ids][:, 0]
    return max(17, int((int(c['sh_g']) + 10 + ej - ein).max()))


def product_shifts(c, groups, ids):
    eout = int(c['silu_member'][1])
    eoj = groups[ids][:, 1]
    own = int(c['sh_h']) - 8 - (eoj - eout)
    return int(own.min()), int(own.max())


def w16r2_widths(sh_ao, sh_s, sh_z, gate):
    """range16::widths for this export's LowH24 precision (CODE mirror, a
    prediction only; the Rust census is the authority): constants 16, 15, 12, 13
    and SH_ROPE 7, plus the top limbs of ao (sh_ao+14), down (sh_z+14), score
    (sh_s+12) and the gate; wrho_s = 7 + f_e 9 = 16."""
    w = {16, 15, 12, 13, 7}
    for bits in (sh_ao + 14, sh_z + 14, sh_s + 12, gate):
        if bits > 16:
            w.add(bits - 16)
        else:
            w.add(bits)
    w.discard(8)
    return sorted(w)


def inputs(kind):
    """(rows, offsets, ids) of the 4,872 A1 evaluation rows or the 192
    calibration sequences (kept apart: different directories and digests)."""
    directory = EXPORT_LANE / ('evaluation_inputs' if kind == 'evaluation' else 'calibration_replay_inputs')
    data = read(directory / 'input.json')
    for name, key in (('ids.npy', 'ids_sha256'), ('offsets.npy', 'offsets_sha256')):
        require(sha(directory / name) == data[key], 'input digest differs')
    offsets = np.load(directory / 'offsets.npy', allow_pickle=False)
    ids = np.load(directory / 'ids.npy', allow_pickle=False)
    rows = data['rows']
    require(len(offsets) == len(rows) + 1 and offsets[0] == 0 and int(offsets[-1]) == len(ids), 'offsets')
    require(all(int(t) == r['T'] for t, r in zip(np.diff(offsets), rows)), 'row lengths')
    if kind == 'evaluation':
        require(len(rows) == 4872 and len(ids) == 702006, 'full A1 coverage')
    else:
        require(len(rows) == 192 and all(r['dataset'] == 'calibration' for r in rows), 'calibration coverage')
    return rows, offsets, ids
