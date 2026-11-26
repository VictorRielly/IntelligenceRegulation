"""Build the W16R2 guest's Python source archive from an explicit list of public files."""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
APP = Path('apps/proven-media')
MODULES = (
    '__init__', 'base_sepolia', 'classifier_cli', 'config', 'image_preprocess', 'items',
    'manifest', 'prompting', 'proof_plans', 'provers', 'publisher', 'records',
    'shieldstral_fast_runtime', 'shieldstral_runtime', 'shieldstral_text', 'testnet_publisher',
    'tokenizer', 'w16r2_export', 'w16r2_public_verifier', 'w16r2_runtime',
)
TOOLS = ('prepare_w16r2_verifier', 'verify_manifest', 'verify_publication')


def source_files():
    return sorted([
        Path('LICENSE'), Path('NOTICE'), Path('scripts/zk60_resource_guard.py'),
        Path('results/zk60_shieldstral_export_20261026/category_policy_candidates.json'),
        APP/'requirements.txt', APP/'requirements-testnet.txt', APP/'deploy.json',
        APP/'proven_media/w16r2_native_intake.json',
        *(APP/'proven_media'/f'{name}.py' for name in MODULES),
        *(APP/'tools'/f'{name}.py' for name in TOOLS),
        *(APP/'policy'/f'shieldstral-moderate-{name}-v1.txt' for name in ('sexual','violence','hate')),
    ])


def package():
    buffer = io.BytesIO()
    paths = source_files()
    with gzip.GzipFile(fileobj=buffer,mode='wb',mtime=0,filename='') as gz:
        with tarfile.open(fileobj=gz,mode='w|',format=tarfile.USTAR_FORMAT) as archive:
            for relative in paths:
                path = ROOT/relative
                if path.resolve(strict=True) != path or not path.is_file():
                    raise ValueError(f'Expected a regular public source file at {relative}')
                raw = path.read_bytes()
                member = tarfile.TarInfo(str(relative))
                member.mode, member.size = 0o644, len(raw)
                archive.addfile(member, io.BytesIO(raw))
    raw = buffer.getvalue()
    return raw, {'files':len(paths), 'bytes':len(raw), 'sha256':hashlib.sha256(raw).hexdigest()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive',type=Path)
    args = parser.parse_args()
    raw, report = package()
    with args.archive.open('xb') as stream:
        stream.write(raw)
    print(json.dumps(report,indent=2))
