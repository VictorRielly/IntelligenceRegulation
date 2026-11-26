#!/usr/bin/env python3
"""Prepare or authenticate the Mac W16R2 binary, public export and source checkpoint."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from proven_media import records, w16r2_export as exports, w16r2_runtime as runtime
from proven_media.provers import ProverError


def check(kit):
    intake = runtime.authority()
    model_files = dict(exports.public_files(kit / 'export', runtime.PROFILE_SHA))
    files = {Path('export') / name: digest for name, digest in model_files.items()}
    profile = json.loads((kit / 'export/profile.json').read_bytes())
    files[Path('models') / exports.CHECKPOINT] = profile['model']['sha256']
    files[exports.KIT_BINARY] = intake['binary_sha256']

    # Compare directory entries too, so an unrelated document or hidden file
    # cannot travel in a package that has passed this check.
    children = {}
    for name in files:
        for child in (name, *name.parents):
            if child != Path('.'):
                children.setdefault(child.parent, set()).add(child.name)
    for folder, names in children.items():
        directory = kit / folder
        if directory.is_symlink() or {p.name for p in directory.iterdir()} != names:
            raise ValueError(f'unexpected or missing verifier kit entries in {folder}')
    sizes = {}
    for name, digest in files.items():
        path = kit / name
        if path.is_symlink() or not path.is_file() or records.sha256_file(path) != digest:
            raise ValueError(f'verifier kit digest or file type differs for {name}')
        sizes[name.parts[0]] = sizes.get(name.parts[0], 0) + path.stat().st_size
    if not os.access(kit / exports.KIT_BINARY, os.X_OK):
        raise ValueError('the pinned verifier is missing its execute permission')
    return dict(accepted=True, scope='w16r2_verifier_kit_files', files=len(files), bytes=sum(sizes.values()),
                bytes_by_directory=sizes, binary_sha256=intake['binary_sha256'],
                profile_sha256=runtime.PROFILE_SHA, checkpoint_sha256=profile['model']['sha256'])


def prepare(kit):
    if kit.exists() or kit.is_symlink():
        raise ValueError('preparation needs a new directory; use --check for an existing kit')
    runtime.authority()
    kit.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.w16r2-kit-', dir=kit.parent) as scratch:
        stage = Path(scratch) / 'kit'
        stage.mkdir()
        export = Path(scratch) / 'export'
        exports.prepare(runtime.EXPORT, export, runtime.PROFILE_SHA)
        export.rename(stage / 'export')
        checkpoint = Path('models') / exports.CHECKPOINT
        for source, name, mode in ((runtime.BINARY, exports.KIT_BINARY, 0o755),
                                   (runtime.baseline.NATIVE_MODELS / exports.CHECKPOINT, checkpoint, 0o644)):
            target = stage / name
            target.parent.mkdir(parents=True)
            shutil.copyfile(source, target)
            target.chmod(mode)
        result = check(stage)
        stage.rename(kit)
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kit', type=Path)
    parser.add_argument('--check', action='store_true', help='authenticate an existing kit')
    args = parser.parse_args()
    kit = args.kit.absolute()
    try:
        if kit.is_symlink():
            raise ValueError('verifier kit path must name its directory directly')
        result = (check if args.check else prepare)(kit.parent.resolve() / kit.name)
    except (OSError, ProverError, ValueError) as exc:
        print(json.dumps({'accepted': False, 'scope': 'w16r2_verifier_kit_files', 'reason': str(exc)}))
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
