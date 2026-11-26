"""Rebuild the guest ZIP and exercise the published command in a fresh directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

from build_sample import HERE, MANIFEST_SHA256, READER_FILES, build, pinned

KEY = '32c026629c724e2b9ccac8670e54c1c2349110733b011065cd97ff37ac451d90'
RELEASE = HERE / 'proven-media-signature-example.zip'


def check(interpreter):
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        rebuilt = work / 'rebuilt.zip'
        build(rebuilt)
        if rebuilt.read_bytes() != RELEASE.read_bytes():
            raise ValueError('Guest ZIP differs from the reproducible build')
        root = work / 'proven-media-signature-example'
        with zipfile.ZipFile(RELEASE) as archive:
            expected = sorted(f'{root.name}/{name}' for name in (*READER_FILES, 'README.md', 'sample/manifest.json'))
            if archive.namelist() != expected or archive.testzip() is not None:
                raise ValueError('Guest ZIP inventory differs')
            archive.extractall(work)
        sample = root / 'sample/manifest.json'
        original = json.loads(pinned(sample, MANIFEST_SHA256))
        env = {k: v for k, v in os.environ.items() if not k.startswith(('PM_', 'PYTHON', 'HL_', 'ZK60_'))}
        env.update(PM_PRIVATE_DIR=str(work / 'unused-private'), PM_PUBLIC_DIR=str(work / 'unused-public'))

        def verify(path, key, expect):
            run = subprocess.run([interpreter, '-I', '-B', 'apps/proven-media/tools/verify_manifest.py',
                                  path, '--signature-only', '--public-key', key],
                                 cwd=root, env=env, capture_output=True, text=True, timeout=30)
            report = json.loads(run.stdout)
            if (run.returncode, report.get('accepted'), report.get('scope')) != (
                    0 if expect else 1, expect, 'publisher_signature_only'):
                raise ValueError(f'Unexpected signature result for {path.name}')
            return report['checks']

        honest = verify(sample, KEY, True)
        wrong_key = verify(sample, '00' * 32, False)
        changed = json.loads(sample.read_bytes())
        changed['labels']['hate']['value'] = 'yes'
        altered = work / 'changed.json'
        altered.write_text(json.dumps(changed))
        wrong_label = verify(altered, KEY, False)
        if not all(honest.values()) or wrong_key['issuer_key'] or wrong_label['signature']:
            raise ValueError('Unexpected publisher-key or signature checks')
        if (work / 'unused-private').exists() or (work / 'unused-public').exists():
            raise ValueError('Signature check created an app data directory')
        return {'zip_bytes': RELEASE.stat().st_size, 'sha256': hashlib.sha256(RELEASE.read_bytes()).hexdigest(),
                'files': len(expected), 'signed_manifest_bytes': sample.stat().st_size,
                'scope': 'publisher_signature_only', 'labels': original['labels'],
                'wrong_key_refused': True, 'changed_label_refused': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python', default=sys.executable)
    print(json.dumps(check(parser.parse_args().python), indent=2))
