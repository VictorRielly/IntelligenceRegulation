#!/usr/bin/env python3
"""Replay the accepted 4751b93 toy receipt into schema 3 on the CPU path."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'scripts'))
import zk60_native_capture as native


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    assert not (OUT / 'capture-validation.json').exists()
    assert not (OUT / 'captures').exists()
    prior = ROOT / 'results/zk60_host_private_20260920/main-gate'
    d = json.loads((prior / 'validation.json').read_text())
    assert d['state'] == 'passed' and (prior / 'run.done').read_text().strip() == '0'
    for p, h in d['source_hashes'].items():
        assert sha(ROOT / p) == h, p
    candidates = [(ROOT / p, h) for p, h in d['binary_hashes'].items() if '/deps/hashline-' in p]
    assert len(candidates) == 1
    binary, binary_sha = candidates[0]
    assert sha(binary) == binary_sha
    source = subprocess.check_output(['git', 'rev-parse', '4751b93'], cwd=ROOT, text=True).strip()
    receipt = prior / 'native-block/block_receipt.bin'
    expected = prior / 'native-block/block_expected.bin'
    row = next(r for r in d['native_receipts'] if r['profile'] == 'block')
    for p, h in row['files'].items():
        assert sha(prior / p) == h
    env = {k: v for k, v in os.environ.items() if not k.startswith('HL_')}
    env.update(RAYON_NUM_THREADS='2', HL_TEST_SOURCE_COMMIT=source,
               HL_TEST_NATIVE_RECEIPT=str(receipt), HL_TEST_NATIVE_EXPECTED=str(expected),
               HL_TEST_NATIVE_CAPTURES=str(OUT / 'captures'))
    argv = [str(binary), '--exact', 'private_block::capture::native_capture_saved_receipt', '--ignored', '--nocapture']
    with (OUT / 'capture.log').open('x') as f:
        r = subprocess.run(argv, cwd=ROOT, env=env, stdout=f, stderr=subprocess.STDOUT, timeout=60)
    (OUT / 'capture.done').write_text(str(r.returncode) + '\n')
    assert r.returncode == 0 and '1 passed; 0 failed; 0 ignored' in (OUT / 'capture.log').read_text()
    captures = list((OUT / 'captures').glob('*.json'))
    assert len(captures) == 1
    accepted = native.check_bundle(captures[0], source, binary, binary_sha)
    assert sha(binary) == binary_sha
    for p, h in d['source_hashes'].items():
        assert sha(ROOT / p) == h, p
    report = dict(state='passed', source_commit=source, source_hashes=d['source_hashes'],
                  verifier_test_binary=str(binary), verifier_sha256=binary_sha,
                  execution='CPU path; GPU feature compiled but every HL_* runtime flag stripped',
                  argv=argv, accepted=accepted, runner_sha256=sha(Path(__file__)),
                  artifacts={str(p.relative_to(OUT)): {'sha256': sha(p), 'bytes': p.stat().st_size}
                             for p in (OUT / 'captures').iterdir()},
                  capture_log_sha256=sha(OUT / 'capture.log'), privacy_extension=False)
    (OUT / 'capture-validation.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(json.dumps(dict(state='passed', accepted=accepted, execution=report['execution'])))


if __name__ == '__main__':
    main()
