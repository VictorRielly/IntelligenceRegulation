#!/usr/bin/env python3
"""Independently check the completed isolated candidate and retained gate logs."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

MAIN = Path(__file__).resolve().parents[2]
ROOT = Path('/tmp/wt-zk60-host-private-20260920')
OUT = ROOT / 'results/zk60_host_private_20260920'
HERE = Path(__file__).resolve().parent
FROZEN = {
    'v2': ('50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d', 66844928),
    'v3': ('5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d', 70758084),
    'legacy-zk': ('021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d', 87228528),
    'legacy-zkv3': ('40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17', 87697008),
}


def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def totals(log):
    rows = re.findall(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored', log)
    assert rows
    return tuple(sum(int(row[i]) for row in rows) for i in range(3))


def main():
    d = json.loads((OUT / 'validation.json').read_text())
    assert d['state'] == 'passed' and (OUT / 'run.done').read_text().strip() == '0'
    for key, root in [('source_hashes', ROOT), ('binary_hashes', ROOT), ('main_binary_hashes', MAIN)]:
        for p, h in d[key].items():
            assert sha(root / p) == h, p
    assert sha(OUT / 'run.py') == d['runner_sha256'] == sha(HERE / 'candidate-run.py')
    assert sha(ROOT / 'results/zk60_fsp_l9_integration_20260919/run.py') == d['reference_sha256']
    runs = {r['name']: r for r in d['runs']}
    assert len(runs) == len(d['runs']) == 43
    logs = {}
    for name, r in runs.items():
        p = OUT / (name + '.log')
        assert r['exit_code'] == 0 and (OUT / (name + '.done')).read_text().strip() == '0', name
        assert sha(p) == r['log_sha256'], name
        logs[name] = p.read_text()
    assert totals(logs['storage-tests']) == (307, 0, 2)
    for pool in ('0', '1'):
        for fold in ('0', '1'):
            for group in ('zk-fresh_poc-io-tests', 'zk-mr1_probe_tests'):
                name = 'cpu-' + group + '-' + pool + fold
                assert totals(logs[name]) == (6, 0, 0)
                assert runs[name]['environment'] == {'HL_FSP_POOL': pool, 'HL_FSP_I8FOLD': fold}
    for group, count in [('zk-zkhostbuf-tests', 1), ('gpu-planes-tests', 5), ('wcache-tests', 3), ('private_block-norm_alias', 5)]:
        assert totals(logs['cpu-' + group]) == (count, 0, 0)
    assert totals(logs['gpu-upload-host-oracles']) == (3, 0, 0)
    assert totals(logs['gpu-commit']) == (34, 0, 0)
    assert totals(logs['gpu-cache']) == (12, 0, 0)
    rows = [json.loads(s.removeprefix('ZK60_CL4_SUMMARY ')) for s in logs['gpu-commit'].splitlines() if s.startswith('ZK60_CL4_SUMMARY ')]
    assert len(rows) == 1 and rows[0]['executed_cases'] == 189
    assert rows[0]['gpu_enabled'] and rows[0]['gpu_required']
    gates = {g['name']: g for g in d['proof_gates']}
    want = {arm + '-' + profile: values for arm in ('cpu', 'gpu', 'gpu-chunked') for profile, values in FROZEN.items()}
    want.update({route + '-' + arm: FROZEN['v3'] for route in ('resident', 'streamed') for arm in ('planes', 'planes-off', 'narrow-off')})
    want.update({'gpu-plane-cache-' + arm: FROZEN['v3'] for arm in ('cold', 'warm')})
    assert set(gates) == set(want) and len(d['proof_gates']) == 20
    for name, (digest, size) in want.items():
        g = gates[name]
        assert g['accepted'] and (g['sha256'], g['bytes']) == (digest, size), name
        assert re.search(r'PASS(?:-V3)? ACCEPT', logs[name]), name
        if not name.startswith('cpu-'):
            assert 'gpu: ON' in logs[name]
        if name.startswith('gpu-chunked-'):
            if 'legacy' in name:
                assert 'CHUNKED (forced)' in logs[name]
            else:
                assert re.search(r'chunked commits [1-9][0-9]*', logs[name])
    for route in ('resident', 'streamed'):
        for arm in ('planes', 'planes-off', 'narrow-off'):
            log = logs[route + '-' + arm]
            lines = [s for s in log.splitlines() if 'conv W ' in s]
            assert len(lines) == 12 and all(('[planes]' in s) == (arm == 'planes') for s in lines)
            marker = 'whole-buffer narrow upload' if route == 'resident' else 'streamed commit rows'
            assert any(marker in s and '(int8 planes)' in s for s in log.splitlines()) == (arm == 'planes')
    for arm in ('cold', 'warm'):
        log = logs['gpu-plane-cache-' + arm]
        assert ('hits 0 | misses 12' if arm == 'cold' else 'hits 12 | misses 0') in log
    assert len(d['probes']) == 2
    for backend in ('cpu', 'gpu'):
        rows = [json.loads(s.removeprefix('PROBE_JSON ')) for s in logs[backend + '-repaired-probe'].splitlines() if s.startswith('PROBE_JSON ')]
        assert len(rows) == 3 and {r['arm'] for r in rows} == {'public', 'legacy', 'repaired'}
        assert all(r['accept'] and r['layers'] == 12 and r['tokens'] == 512 and r['gpu'] == (backend == 'gpu') for r in rows)
        assert next(p['rows'] for p in d['probes'] if p['backend'] == backend) == rows
    # The added public commitment entry must leave every inherited PCS byte
    # intact, including the private masks/openings named in D22.
    pcs = (ROOT / 'hashline/src/pcs.rs').read_text()
    start = pcs.index('/// [FSP-HOST] ITEM (a)')
    end = pcs.index('/// Prover: open `claims`', start)
    old = subprocess.check_output(['git', 'show', '4bf1fa0:hashline/src/pcs.rs'], cwd=MAIN, text=True)
    assert pcs[:start] + pcs[end:] == old
    result = dict(state='passed', candidate='3d5c60c', source_hashes_checked=len(d['source_hashes']),
                  candidate_binaries_checked=len(d['binary_hashes']), main_binaries_unchanged=len(d['main_binary_hashes']),
                  logs_checked=len(logs), frozen_proof_gates=20, device_cases=189, storage_totals=[307, 0, 2],
                  probe_arms=6, inherited_pcs_source_identical=True,
                  proof_hash_scope='Checked by pinned runner before deleting its own scratch proofs; manifest expectations and logs rechecked here.',
                  privacy_acceptance=False, model_scale_speed_claim=False)
    (HERE / 'audit.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
