#!/usr/bin/env python3
"""Retain the device-checked candidate and public test fixtures for new hosts."""
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SOURCE = Path('/tmp/zk60-sol-gpu-20260927')
BASELINE = Path('/tmp/zk60-groups-20260926')
EVIDENCE = REPO / 'results/zk60_sol_gpu_20260927/attempt-2'
NAME = 'zk60-keyed-cuda-development-20260927'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    report = json.loads((EVIDENCE / 'device_report.json').read_text())
    assert report['status'] == 'passed'
    assert (EVIDENCE / 'device.done').read_text().strip() == '0'
    pins = report['pins']['sources']
    for rel, expected in pins.items():
        assert digest((SOURCE / rel).read_bytes()) == expected, rel
    payload = {}
    for crate in ('hashline', 'zkp-core', 'private-block-kernel', 'private-block-kernel-shaped'):
        for root, dirs, names in os.walk(SOURCE / crate):
            dirs[:] = sorted(d for d in dirs if d not in ('target', '.git', '__pycache__'))
            for name in sorted(names):
                path = Path(root) / name
                assert path.is_file() and not path.is_symlink(), path
                payload[str(path.relative_to(SOURCE))] = path.read_bytes()
    # These are public synthetic statements and a source-count fixture, not
    # private witnesses, trained weights, or hundreds of MB of proof segments.
    fixture_names = (
        'm125-run-l12-tagged-run-statement.json',
        'm125-run-l12-dense-run-statement.json',
        'x34-slot-ir/drafter_inventory.tsv',
    )
    for name in fixture_names:
        rel = 'results/zk60_block125m_lane/' + name
        payload[rel] = (BASELINE / rel).read_bytes()
    # The compatibility test also needs an actual historical synthetic toy
    # receipt and its public endpoint policy; a newly generated receipt would
    # not exercise cross-version compatibility.
    for name in ('block_receipt.bin', 'block_expected.bin'):
        rel = 'results/zk60_rowfold_20260919/integration/native-block-0/' + name
        payload[rel] = (BASELINE / rel).read_bytes()
    payload['HOST_SETUP.md'] = (REPO / 'docs/zkmatrix-poc/ZK60_HARDWARE_SETUP.md').read_bytes()
    payload['zk60_host_preflight.py'] = (REPO / 'scripts/zk60_host_preflight.py').read_bytes()
    payload['README.md'] = (HERE / 'SNAPSHOT_README.md').read_bytes()
    payload['SOURCE_MANIFEST.json'] = (json.dumps({
        'kind': 'development source snapshot; not a full-model or privacy acceptance',
        'candidate_source_pins': pins,
        'files': {rel: digest(data) for rel, data in sorted(payload.items())},
        'device_evidence_sha256': digest((EVIDENCE / 'device_report.json').read_bytes()),
        'device_evidence': 'results/zk60_sol_gpu_20260927/attempt-2/device_report.json in the parent repository',
    }, indent=2) + '\n').encode()
    archive = HERE / (NAME + '.tar.gz')
    with archive.open('wb') as raw:
        with gzip.GzipFile(filename='', fileobj=raw, mode='wb', mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w') as tar:
                for rel, data in sorted(payload.items()):
                    item = tarfile.TarInfo(NAME + '/' + rel)
                    item.size = len(data)
                    item.mode = 0o644
                    item.mtime = 0
                    tar.addfile(item, io.BytesIO(data))
    # Read the actual compressed artifact back, verifying every member before
    # publishing its checksum. No extraction or code execution is involved.
    with tarfile.open(archive, 'r:gz') as tar:
        assert len(tar.getmembers()) == len(payload)
        for member in tar:
            rel = member.name.removeprefix(NAME + '/')
            assert member.isfile() and rel in payload
            assert tar.extractfile(member).read() == payload[rel]
    sha = digest(archive.read_bytes())
    (HERE / (archive.name + '.sha256')).write_text(f'{sha}  {archive.name}\n')
    print(json.dumps({'archive': str(archive), 'bytes': archive.stat().st_size,
                      'files': len(payload), 'sha256': sha}, indent=2))


if __name__ == '__main__':
    main()
