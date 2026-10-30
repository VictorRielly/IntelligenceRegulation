"""Validate the diagnosed group-fixture correction without overwriting attempt3.

Every native leaf uses the reviewed guard. Source, executable and commands
are pinned; any failure stops the batch. No profile registration is performed.
"""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TREE = HERE / 'checkpoints/final-build-1/tree'
OUT = HERE / 'final-arithmetic-2'
BUILD = 'sol-r14-final-build-1'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
GUARD_SHA = '67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3'
ATTACK = 'private_block::argument::split_attack_tests::split_run_t128_malicious_arithmetic_receipt_from_env'
FIXTURE = 'private_block::argument::split_attack_tests::split_local_group_fixture_has_distinct_outputs'
DENSE = 'private_block::argument::split_dense_tests::split_generic_dense_t128_native_receipt_and_physical_trace'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, data):
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(data, indent=2) + '\n')
    temp.replace(path)


def main():
    assert not OUT.exists(), 'inspect existing attempt; never automatically retry'
    guard_review = json.loads((HERE / 'GUARD_DISK_CONTINUITY.json').read_text())
    assert guard_review['guard_sha256'] == GUARD_SHA and guard_review['validation_passed'] is True
    OUT.mkdir()
    pin = json.loads((HERE / (BUILD + '.source.json')).read_text())
    build = json.loads((HERE / 'final-validation-1/ACCEPTANCE.json').read_text())
    assert (HERE / 'final-validation-1/ACCEPTANCE.done').read_text().strip() == '0'
    checkpoint = HERE / 'checkpoints/final-build-1'
    binary = checkpoint / 'hashline.test.bin'
    assert build['source'] == pin['tree_sha256'] and sha(binary) == build['test_binary_sha256']
    binary_sha = sha(binary)
    script_sha = sha(Path(__file__))
    reference_sha = sha(HERE / 'generic_reference.py')
    records = []
    previous = HERE / 'final-arithmetic-1'
    retained = {row['name']: row for row in json.loads((previous/'progress.json').read_text())['records']}
    shutil.copytree(previous/'receipts', OUT/'receipts')


    def check():
        assert sha(GUARD) == GUARD_SHA
        assert sha(binary) == binary_sha
        assert sha(Path(__file__)) == script_sha
        assert sha(HERE / 'generic_reference.py') == reference_sha
        for name, want in pin['files'].items():
            assert sha(TREE / name) == want, name
            assert sha(checkpoint / 'tree' / name) == want, name

    check()
    save(OUT / 'contract.json', {'source': pin['tree_sha256'], 'files': len(pin['files']),
         'binary_sha256': binary_sha, 'script_sha256': script_sha,
         'reference_sha256': reference_sha, 'guard_sha256': GUARD_SHA,
         'scope': 'Final-source native malformed arithmetic/C3 receipts and dense19site/reference acceptance; no privacy or release acceptance'})

    def run(name, leaf, need, cap):
        check()
        if name in retained:
            row = dict(retained[name])
            assert row['guard']['exit'] == row['guard']['child_rc'] == 0
            assert row['log_sha256'] == sha(previous/(name+'.log'))
            command = json.loads((previous/(name+'.command.json')).read_text())
            assert command['source'] == pin['tree_sha256'] and command['binary_sha256'] == binary_sha
            row['retained_from'] = str(previous.relative_to(HERE))
            records.append(row)
            return (previous/(name+'.log')).read_text()
        label = 'sol-r14-final-arithmetic2-' + name + '-1'
        cls = 'cpu' if need >= 1 else 'light'
        command = [sys.executable, str(GUARD), 'run', '--class', cls,
                   '--label', label, '--need-gib', str(need), '--cap-gib', str(cap),
                   '--wait-secs', '3600', '--max-secs', '1800',
                   '--log', str(OUT / (name + '.log')), '--done', str(OUT / (name + '.done')),
                   '--result-json', str(OUT / (name + '.guard.json')), '--', *leaf]
        record = OUT / (name + '.command.json')
        assert not record.exists()
        save(record, {'command': command, 'source': pin['tree_sha256'], 'binary_sha256': binary_sha})
        while True:
            check()
            status = json.loads(subprocess.check_output([sys.executable, str(GUARD), 'status', '--json'], cwd=ROOT, text=True))
            lean = all(j['class'] == 'light' and j['need_gib'] <= 1 for j in status['live_guarded_jobs'])
            holds = (HERE / 'HOLD').exists() or (HERE.parent / 'HOLD').exists()
            if lean and not holds:
                break
            print(datetime.now(timezone.utc).isoformat(), name, 'waiting for shared heavy slot / lane hold', flush=True)
            time.sleep(10)
        result = subprocess.run(command, cwd=ROOT)
        check()
        guard = json.loads((OUT / (name + '.guard.json')).read_text())
        assert result.returncode == 0 and guard['exit'] == 0, (name, result.returncode)
        log = (OUT / (name + '.log')).read_text()
        records.append({'name': name, 'guard': guard, 'log_sha256': sha(OUT / (name + '.log'))})
        save(OUT / 'progress.json', {'utc': datetime.now(timezone.utc).isoformat(),
             'source': pin['tree_sha256'], 'records': records})
        print(name, 'native leaf PASS', flush=True)
        return log

    def native(name, test, dd, extra, need, cap):
        log = run(name, ['/usr/bin/env', 'RAYON_NUM_THREADS=8', 'OPENBLAS_NUM_THREADS=1',
                        'HL_R14_DD=' + str(int(dd)), *extra, str(binary), test,
                        '--exact', '--ignored', '--nocapture', '--test-threads=1'], need, cap)
        assert '1 passed; 0 failed' in log
        return log

    # A witness-only check diagnoses degeneration before any expensive proof.
    for dd in [False, True]:
        mode = 'dd' if dd else 'non-dd'
        log = native('fixture-' + mode, FIXTURE, dd, [], 2, 3.5)
        assert 'R14_GROUP_FIXTURE ' in log

    attacks = []
    for dd in [False, True]:
        mode = 'dd' if dd else 'non-dd'
        for attack in ['per-piece-round-q', 'local-c2-ao', 'one-piece-norm',
                       'wrong-omitted-source-bit', 'missing-public-lift-gate', 'local-group-reset',
                       'wrong-feature-axis', 'wrong-global-fold-offset']:
            out = OUT / 'receipts' / mode / attack
            group = attack == 'local-group-reset'
            log = native(mode + '-' + attack, ATTACK, dd,
                         ['HL_R14_ATTACK=' + attack] + ([] if group else ['HL_R14_ATTACK_OUTPUT=' + str(out)]),
                         9 if group else 7.5, 11.5 if group else 10)
            assert 'R14_ATTACK_REFUSAL ' + attack + ':' in log
            receipts = [json.loads(line.split('R14_MALICIOUS_RECEIPT ', 1)[1])
                        for line in log.splitlines() if 'R14_MALICIOUS_RECEIPT ' in line]
            assert len(receipts) == (3 if group else 1)
            assert sum(not r['expected_accept'] for r in receipts) == 1
            assert all(r['canonical_frame_decoded'] and r['native_verifier_used'] for r in receipts)
            if not group:
                assert (out / 'segment0.bin').stat().st_size == receipts[-1]['bytes']
            attacks.append({'dd': dd, 'case': attack, 'receipts': receipts,
                            'sha256': None if group else sha(out / 'segment0.bin'), 'frame_retained': not group})
            save(OUT / 'malformed-receipts.progress.json', attacks)
    save(OUT / 'MALFORMED_RECEIPTS.json', {'source': pin['tree_sha256'], 'binary_sha256': binary_sha,
         'cases': attacks, 'scope': '16 complete canonical receipts rejected by final-source native verifier, including C3 axes/folds;4 honest group controls verify. Group cases omit output env to avoid test-only accepted-control path collision; their complete frames are natively decoded/verified in memory, not retained on disk.'})
    (OUT / 'MALFORMED_RECEIPTS.done').write_text('0\n')

    dense_rows = []
    for dd in [False, True]:
        mode = 'dd' if dd else 'non-dd'
        out = OUT / 'dense' / mode
        log = native('dense-' + mode, DENSE, dd, ['HL_R14_DENSE_TRACE_OUTPUT=' + str(out)], 7.2, 10)
        traces = [json.loads(line.split('R14_GENERIC_TRACE ', 1)[1])
                  for line in log.splitlines() if 'R14_GENERIC_TRACE ' in line]
        assert len(traces) == 19 and len({r['site'] for r in traces}) == 19
        receipts = [json.loads(line.split('R14_MALICIOUS_RECEIPT ', 1)[1])
                    for line in log.splitlines() if 'R14_MALICIOUS_RECEIPT ' in line]
        assert len(receipts) == 1 and receipts[0]['expected_accept']
        dense_rows.append({'dd': dd, 'traces': traces, 'receipts': receipts})
        if not dd:
            run('dense-reference', ['/usr/bin/env', 'OPENBLAS_NUM_THREADS=1', sys.executable,
                str(HERE / 'generic_reference.py'), str(out), str(OUT / 'DENSE_REFERENCE.json')], 1.4, 3)
    reference = json.loads((OUT / 'DENSE_REFERENCE.json').read_text())
    assert reference['differences'] == 0 and len(reference['sites']) == 19
    want = {r['site']: r['sha256'] for r in reference['sites']}
    for row in dense_rows:
        assert {r['site']: r['sha256'] for r in row['traces']} == want
    save(OUT / 'DENSE_ACCEPTANCE.json', {'source': pin['tree_sha256'], 'binary_sha256': binary_sha,
         'cases': dense_rows, 'reference': 'DENSE_REFERENCE.json'})
    (OUT / 'DENSE_ACCEPTANCE.done').write_text('0\n')
    save(OUT / 'ACCEPTANCE.json', {'utc': datetime.now(timezone.utc).isoformat(), 'source': pin['tree_sha256'],
         'binary_sha256': binary_sha, 'records': records,
         'scope': 'Final-source group fixtures,16 DD/nonDD arithmetic/C3 malformed receipts,4 honest group contexts,2 dense native receipts and19site independent parity pass.',
         'pending': 'Independent review, full26/captures/whole count, global rank/CFS/NL1/privacy, freeze and registration remain separate'})
    (OUT / 'done').write_text('0\n')


if __name__ == '__main__':
    try:
        main()
    except BaseException as error:
        if OUT.exists():
            save(OUT / 'failure.json', {'utc': datetime.now(timezone.utc).isoformat(), 'error': repr(error)})
            (OUT / 'done').write_text('1\n')
        raise
