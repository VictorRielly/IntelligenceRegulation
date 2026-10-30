"""Compare the actual layer25 candidate with the independent native intake.

This is a public-array/table check, not native weight import or proof acceptance.
It does not rewrite the earlier full-layer audit pinned by the native adapter.
"""
import json
from pathlib import Path

import numpy as np

from amended_evaluator import candidate_pin
from collect_stats import atomic_json, sha

HERE = Path(__file__).resolve().parent
NATIVE = HERE.parent / 'zk60_1b_native_20261017/r13'


def main():
    candidate = HERE / 'layer25_fix_candidate'
    pin = candidate_pin(candidate)
    meta = json.loads((candidate / 'complete.json').read_text())
    intake = NATIVE / 'shieldstral-intake-arrays'
    manifest = json.loads((intake / 'manifest.json').read_text())
    if manifest['audit_sha256'] != sha(HERE / 'native_candidate_audit.json'):
        raise ValueError('native intake uses a different full-layer audit')
    if manifest['candidate_sha256'] != meta['candidate_sha256']:
        raise ValueError('native intake uses a different calibration candidate')
    if [row['index'] for row in manifest['layers']] != list(range(26)):
        raise ValueError('native intake lacks the expected layer ordering')
    row = manifest['layers'][25]
    if row['constants'] != meta['constants'] or row['constants']['sh_u'] != 0 or row['constants']['sh_h'] != 15:
        raise ValueError('native intake uses different layer25 constants')
    evidence = {}
    with np.load(candidate / 'candidate.npz', allow_pickle=False) as arrays:
        expected = {'m_u': arrays['mult_u'], 'silu_group_ids': arrays['group_ids'],
                    'silu_groups': np.array(meta['group_members']), 'act': arrays['group_tables']}
        for name, value in expected.items():
            spec = row['arrays'][name]
            dtype = '<i2' if name == 'act' else '<i8'
            if spec['file'] != name + '.bin' or spec['shape'] != list(value.shape) or spec['dtype'] != ('int16' if name == 'act' else 'int64'):
                raise ValueError('native array representation differs: ' + name)
            path = intake / row['directory'] / spec['file']
            if sha(path) != spec['sha256'] or path.read_bytes() != value.astype(dtype).tobytes(order='C'):
                raise ValueError('native payload differs from actual candidate: ' + name)
            evidence[name] = spec
        tables = arrays['group_tables']
        fixture_evidence = []
        for group, table in zip(meta['group_members'], tables):
            fixture = NATIVE / 'working-tree/hashline/src/private_block/r13_vectors' / f'silu_{group[0]}_{group[1]}.bin'
            if fixture.read_bytes() != table.astype('<i2').tobytes():
                raise ValueError('candidate differs from independent native SiLU fixture')
            fixture_evidence.append({'member': group, 'sha256': sha(fixture), 'words': len(table),
                                     'minimum': int(table.min()), 'maximum': int(table.max())})
    guard = json.loads((NATIVE / 'registry-integrated.guard.json').read_text())
    if (NATIVE / 'registry-integrated.done').read_text().strip() != '0' or guard['exit'] != 0 or guard['child_rc'] != 0:
        raise ValueError('native registry test run did not complete successfully')
    log = (NATIVE / 'registry-integrated.log').read_text()
    test = 'shieldstral_member_matches_all_4096_independent_words_without_clipping ... ok'
    if test not in log or '46 passed; 0 failed' not in log:
        raise ValueError('native test evidence lacks the complete new-member comparison')
    result = {'schema': 'zk60-shieldstral-native-layer25-crosscheck/1',
              'scope': 'Exact public-array and independent table-fixture parity; not native weight import, proof or review acceptance',
              'bit_identical': True, 'candidate': pin, 'groups': fixture_evidence,
              'native_intake_arrays': evidence, 'native_intake_sha256': sha(intake / 'manifest.json'),
              'native_registry_test_log_sha256': sha(NATIVE / 'registry-integrated.log'),
              'native_registry_guard_sha256': sha(NATIVE / 'registry-integrated.guard.json'),
              'native_table_source_sha256': sha(NATIVE / 'working-tree/hashline/src/private_block/accuracy_tables.rs'),
              'crosscheck_source_sha256': sha(__file__)}
    atomic_json(HERE / 'native_layer25_crosscheck.json', result)
    print(json.dumps({'bit_identical': True, 'groups': len(fixture_evidence), 'table_words': sum(g['words'] for g in fixture_evidence)}))


if __name__ == '__main__':
    main()
