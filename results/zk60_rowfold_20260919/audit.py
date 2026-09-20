#!/usr/bin/env python3
"""Recheck retained integration artifacts against current source before acceptance."""
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]


def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''):
            h.update(b)
    return h.hexdigest()


def main():
    integration = json.loads((BASE / 'integration/validation.json').read_text())
    storage = json.loads((BASE / 'storage-gate/validation.json').read_text())
    private = json.loads((BASE / 'integration/private-ffn-fold.json').read_text())
    helper = json.loads((BASE / 'integration/floors-v10-tests.json').read_text())
    for d in [integration, storage, private, helper]:
        assert d['state'] == 'passed'
    for d in [integration, storage, helper]:
        for p, h in d['source_hashes'].items():
            assert sha(ROOT / p) == h, p
    for p, h in integration['binary_hashes'].items():
        assert sha(ROOT / p) == h, p
    for r in integration['runs'] + private['runs']:
        assert r['exit_code'] == 0
        assert sha(BASE / 'integration' / (r['name'] + '.log')) == r['log_sha256'], r['name']
    assert len(integration['proof_gates']) == 12
    assert len({g['name'] for g in integration['proof_gates']}) == 12
    assert all(g['accepted'] for g in integration['proof_gates'])
    assert len(integration['native_proofs']) == 4
    for r in integration['native_proofs']:
        d = BASE / 'integration' / ('native-' + r['profile'] + '-' + r['fold_mode'])
        receipt = d / (r['profile'] + '_receipt.bin')
        assert receipt.stat().st_size == r['bytes'] and sha(receipt) == r['sha256']
        assert sha(d / (r['profile'] + '_expected.bin')) == r['policy_sha256']
        assert r['verified_modes'] == ['0', '1']
    assert sha(ROOT / private['binary']) == private['binary_sha256']
    assert [r['tests_passed'] for r in private['runs']] == [6, 6]
    assert sha(BASE / 'integrate.py') == integration['runner_sha256']
    assert sha(BASE / 'attempt-4/validation.json') == integration['benchmark_report_sha256']
    assert sha(ROOT / 'results/zk60_fsp_l9_integration_20260919/run.py') == integration['reference_runner_sha256']
    assert sha(BASE / 'storage-gate.py') == storage['runner_sha256']
    assert sha(BASE / 'storage-gate/storage-tests.log') == storage['log_sha256']
    assert storage['totals'] == {'passed': 288, 'failed': 0, 'ignored': 2}
    assert sha(BASE / 'integration/floors-v10-tests.log') == helper['log_sha256']
    for d in ['integration', 'storage-gate']:
        assert (BASE / d / 'run.done').read_text().strip() == '0'
    out = dict(state='passed', source_pins=len(integration['source_hashes']),
               storage_source_pins=len(storage['source_hashes']),
               proof_gates=12, native_receipts=4, private_ffn_checks_per_mode=6,
               model_scale_speed_claim=False, privacy_acceptance=False,
               report_hashes={p: sha(BASE / p) for p in [
                   'integration/validation.json', 'storage-gate/validation.json',
                   'integration/private-ffn-fold.json', 'integration/floors-v10-tests.json']})
    (BASE / 'integration/audit.json').write_text(json.dumps(out, indent=2) + '\n')
    print(json.dumps(out, indent=2))


if __name__ == '__main__':
    main()
