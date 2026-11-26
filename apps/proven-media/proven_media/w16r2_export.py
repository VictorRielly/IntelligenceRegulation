"""Prepare the W16R2 verifier's public model files on the producing host."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile

from . import records
from .classifier_cli import require


TABLE_MANIFEST_SHA = '00fb42314c69f7ca239a76e1c89d194694b59819ab07ad3288265823c5d9d05a'
KIT_BINARY = Path('bin/zk60_classify')
CHECKPOINT = Path('shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors')


def public_files(source, profile_sha):
    def manifest(relative, digest):
        path = source / relative
        require(path.resolve(strict=True) == path and path.is_file(), 'missing public model manifest')
        raw = path.read_bytes()
        require(hashlib.sha256(raw).hexdigest() == digest, 'public model manifest differs from pin')
        return json.loads(raw)

    profile = manifest('profile.json', profile_sha)
    yield Path('profile.json'), profile_sha
    for index, layer in enumerate(profile['layers']):
        name = layer['dir']
        require(layer['layer'] == index and name == f'layer_{index:02d}', 'unexpected public model layer')
        relative = Path(name) / 'manifest.json'
        model = manifest(relative, layer['manifest_sha256'])
        yield relative, layer['manifest_sha256']
        for entry in model['arrays'].values():
            filename = entry['file']
            require(Path(filename).name == filename and filename.endswith('.bin'), 'unexpected model array name')
            yield Path(name) / filename, entry['sha256']
    tables = manifest('token_io/complete.json', TABLE_MANIFEST_SHA)
    require(tables['profile_sha256'] == profile_sha, 'tied tables belong to another profile')
    yield Path('token_io/complete.json'), TABLE_MANIFEST_SHA
    for filename, digest in tables['files'].items():
        require(Path(filename).name == filename and filename.endswith(('.json','.bin')), 'unexpected tied table name')
        yield Path('token_io') / filename, digest
    token_io = manifest('token_io/token_io.json', tables['files']['token_io.json'])
    yield Path('rotation_sign.bin'), token_io['rotation']['sign_sha256']


def prepare(source, destination, profile_sha):
    def ready():
        require(not destination.is_symlink(), 'verifier export cannot be a symlink')
        if destination.exists():
            require(destination.is_dir(), 'verifier export must be a directory')
            return True
        return False

    if ready():
        return
    require(source.resolve(strict=True) == source and not destination.resolve().is_relative_to(source),
            'verifier export must be separate from the prover export')
    destination.parent.mkdir(parents=True, exist_ok=True)
    lock = destination.with_name('.' + destination.name + '.lock')
    fd = os.open(lock, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        if ready():
            return
        with tempfile.TemporaryDirectory(prefix='.w16r2-',dir=destination.parent) as temporary:
            stage = Path(temporary) / 'export'
            stage.mkdir()
            for relative, digest in public_files(source, profile_sha):
                origin = source / relative
                require(origin.resolve(strict=True) == origin and origin.is_file(), 'public model file is unavailable')
                target = stage / relative
                target.parent.mkdir(exist_ok=True)
                shutil.copyfile(origin, target)
                require(records.sha256_file(target) == digest, 'copied public model file differs from pin')
            stage.rename(destination)
    finally:
        os.close(fd)
