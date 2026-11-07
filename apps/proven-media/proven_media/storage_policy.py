"""Keep app state and proof evidence off volatile paths (D46 crash follow-up).

There is deliberately no environment flag to bypass this startup policy. Unit
tests with synthetic temporary databases patch the app's validator explicitly.
"""
import os
import json
import sys
import tempfile
from pathlib import Path

from . import config

_TEMP_ROOTS = [Path(p) for p in ('/tmp', '/var/tmp', '/dev/shm', '/run')]
if sys.platform == 'darwin':
    _TEMP_ROOTS.extend(Path(p) for p in ('/private/tmp', '/private/var/tmp',
                                       '/var/folders', '/private/var/folders'))
_TEMP_ROOTS.append(Path(tempfile.gettempdir()))
VOLATILE_ROOTS = tuple(set(_TEMP_ROOTS + [p.resolve() for p in _TEMP_ROOTS]))


def durable_path(path: Path, label: str) -> Path:
    original = Path(os.path.abspath(Path(path).expanduser()))
    resolved = original.resolve()
    # A /tmp alias to a durable target also disappears on reboot, so check
    # both the configured path and the symlink-resolved destination.
    if any(p.is_relative_to(root) for p in (original, resolved) for root in VOLATILE_ROOTS):
        raise ValueError(f'{label} must use durable storage, not a temporary directory')
    return resolved


def validate_storage(store=None) -> None:
    private = durable_path(config.PRIVATE_DIR, 'private app root')
    repo = config.REPO.resolve()
    if private.is_relative_to(repo):
        raise ValueError('private app state and openings must be outside the repository')
    private_paths = {
        'database': config.DB_PATH, 'manifest signing key': config.SIGNING_KEY,
        'job and owner files': config.JOBS_DIR, 'private media': config.MEDIA_DIR,
        'salt encryption key': config.PRIVATE_DIR/'app.key',
        'author sessions': config.PRIVATE_DIR/'auth.sqlite3',
    }
    for label, path in private_paths.items():
        if not durable_path(path, label).is_relative_to(private):
            raise ValueError(f'{label} must stay inside the private app root')
    public = durable_path(config.PUBLIC_DIR, 'public proof root')
    if public.is_relative_to(private) or private.is_relative_to(public):
        raise ValueError('public and private storage must not overlap')
    for label, path in {'proof receipts':config.RUNS_DIR, 'public objects':config.STORE_DIR,
                        'public ledger':config.LEDGER_PATH}.items():
        if not durable_path(path, label).is_relative_to(public):
            raise ValueError(f'{label} must stay inside the public proof root')
    if os.environ.get('PM_PUBLISHER', 'local') == 'base-sepolia':
        settings_path = durable_path(Path(os.environ.get('PM_SEPOLIA_CONFIG', '')), 'publisher configuration')
        settings = json.loads(settings_path.read_text())
        wallet = durable_path(settings_path.parent/settings['key_file'], 'testnet signing key')
        if wallet.is_relative_to(repo):
            raise ValueError('testnet signing key must be outside the repository')
    if store is not None:
        for row in store.q('SELECT DISTINCT job_dir FROM jobs WHERE job_dir IS NOT NULL'):
            if not durable_path(row['job_dir'], 'saved job and owner files').is_relative_to(private):
                raise ValueError('saved job and owner files are outside the configured private root')
