"""Build the offline signature example from the released reader and original signed post."""
import argparse
import hashlib
import io
from pathlib import Path
import tarfile
import zipfile

HERE = Path(__file__).resolve().parent
PILOT = HERE.parent / 'app_composed_native_20261122'
READER_SHA256 = 'df6f1ceead22165be82c2cbff456e6459ff9eb943539e7760d1d8377faac9d57'
MANIFEST_SHA256 = 'c6e655cd57c98f87b4c2fb96b54378c3c42c5042ecc8ea31129cd3337e03c09e'
READER_FILES = (
    'LICENSE', 'NOTICE',
    'apps/proven-media/tools/verify_manifest.py',
    'apps/proven-media/proven_media/__init__.py',
    'apps/proven-media/proven_media/config.py',
    'apps/proven-media/proven_media/manifest.py',
    'apps/proven-media/proven_media/records.py',
)


def pinned(path, expected):
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != expected:
        raise ValueError(f'Digest mismatch for {path.name}')
    return data


def build(output):
    reader = pinned(PILOT / 'w16r2-guest-source-12g.tar.gz', READER_SHA256)
    files = {
        'README.md': (HERE / 'QUICKSTART.md').read_bytes(),
        'sample/manifest.json': pinned(PILOT / 'qualification-20261124T082610.220713Z' / 'manifest.json',
                                      MANIFEST_SHA256),
    }
    with tarfile.open(fileobj=io.BytesIO(reader), mode='r:gz') as archive:
        for name in READER_FILES:
            member = archive.getmember(name)
            if not member.isfile():
                raise ValueError(f'Expected a regular reader file at {name}')
            with archive.extractfile(member) as source:
                files[name] = source.read()
    with zipfile.ZipFile(output, 'x', compression=zipfile.ZIP_STORED) as bundle:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo('proven-media-signature-example/' + name)
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            bundle.writestr(entry, data)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    build(parser.parse_args().output)
