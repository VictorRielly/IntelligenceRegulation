"""Bounded support for the installed app's public-fixture qualification."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import time

B = Path(__file__).resolve().parent
ROOT = B.parents[2]
APP = ROOT / 'apps/proven-media'
PRIVATE = Path('/Users/victorrielly/zk60-owner-private/astra-w16r2-app-20261113')
PUBLIC = Path('/Users/victorrielly/zk60-artifacts/astra-w16r2-app-20261113')
HOLDS = [Path('/tmp/HOLD')] + [ROOT / ('results/' + p + '/HOLD') for p in
    ['zk60_astra_20261026', 'zk60_resource_guard', 'zk60_media_app_20261021',
     'zk60_shieldstral_prep_20261021', 'zk60_shieldstral_export_20261026']]


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def authenticate():
    assert len(sys.argv) == 2 and sha(B / 'SOURCES.json') == sys.argv[1], 'source manifest differs'
    sources = json.loads((B / 'SOURCES.json').read_text())
    for name, expected in sources['files'].items():
        assert sha(Path(name)) == expected, name
    return len(sources['files'])


def quiet():
    deadline = time.monotonic() + 3600
    while time.monotonic() < deadline:
        disk_ready = shutil.disk_usage(ROOT).free >= 55 * 2**30
        # Full-command matching also sees queued guard wrappers and can deadlock
        # the heavy-lock owner against a waiting ds4 leaf (resource protocol).
        result = subprocess.run(['/usr/bin/pgrep', 'ds4-bench'], capture_output=True)
        assert result.returncode in (0, 1), 'host quiet check unavailable'
        if disk_ready and result.returncode == 1 and not any(p.exists() for p in HOLDS):
            return {'at': datetime.now(timezone.utc).isoformat(), 'ds4_bench_absent': True,
                    'holds_absent': True, 'scope': 'functional qualification, not a throughput benchmark'}
        time.sleep(10)
    raise TimeoutError('disk floor, HOLD or host quiet wait expired')


def prepare_verifier_export(source, destination, profile_sha):
    """Link the immutable public export; never include private sequence directories."""
    assert not source.is_symlink() and source.resolve(strict=True) == source
    assert sha(source / 'profile.json') == profile_sha
    profile = json.loads((source / 'profile.json').read_text())
    names = ['profile.json', 'rotation_sign.bin', 'token_io'] + [row['dir'] for row in profile['layers']]
    assert len(names) == len(set(names))
    assert all(name == Path(name).name and name not in ('', '.', '..') and not name.startswith('seq_') for name in names)
    paths = []
    for name in names:
        entry = source / name
        assert entry.exists() and not entry.is_symlink()
        paths.extend([entry] + (list(entry.rglob('*')) if entry.is_dir() else []))
    assert all(not p.is_symlink() and (p.is_dir() or stat.S_ISREG(p.stat().st_mode)) for p in paths)
    assert not destination.exists() and not destination.is_symlink()
    temporary = destination.with_name(destination.name + '.preparing')
    temporary.mkdir(parents=True, exist_ok=False)
    try:
        for name in names:
            entry = source / name
            if entry.is_dir():
                shutil.copytree(entry, temporary / name, copy_function=os.link)
            else:
                os.link(entry, temporary / name, follow_symlinks=False)
        assert sha(temporary / 'profile.json') == profile_sha
        temporary.rename(destination)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)


def clean_guard(record):
    assert all(type(record.get(k)) is int and record[k] == 0
               for k in ('exit', 'child_rc', 'stragglers_killed', 'hard_killed'))
    assert record.get('guard_killed') is None and record.get('guard_error') is None
    assert not record.get('refused') and not record.get('gpu_drain_failed')


def verify_public_store(public, post_id, chunks, output):
    results = []
    sentinel = PRIVATE.with_name(PRIVATE.name + '-public-verifier-unused')
    assert not sentinel.exists()
    environment = dict(os.environ, PM_PRIVATE_DIR=str(sentinel), PM_PROVER='stub',
                       PM_FAST_WRITER_MODE='oneshot', HL_A26_VERIFY_ONCE='0', HL_A28_SEAL_AHEAD='0')
    environment.pop('HL_OWNER_PRIVATE_DIR', None)
    assert len(chunks) == 3 and {c['category'] for c in chunks} == {'sexual', 'violence', 'hate'}
    for chunk in chunks:
        category = chunk['category']
        time.sleep(10)
        authenticate()
        quiet()
        command = [sys.executable, '-B', str(APP / 'tools/verify_publication.py'),
                   '--post-id', post_id, '--category', category, '--chunk', str(chunk['index']),
                   '--public-dir', str(public), '--run-verifier']
        run = subprocess.run(command, capture_output=True, text=True, env=environment, timeout=4800)
        path = output / ('public-verifier-' + category)
        path.mkdir()
        (path / 'stdout.json').write_text(run.stdout)
        (path / 'stderr.txt').write_text(run.stderr)
        result = json.loads(run.stdout)
        assert run.returncode == 0 and result['accepted'] is True, category
        proof = result['proof_verifier']
        assert proof['ok'] is True and proof['public_content_only'] is True and proof['production'] is False
        assert proof['fresh_input_owner_check'] is False and proof['reconstructed_receipts_retained'] is False
        clean_guard(proof['guard'])
        evidence = Path(proof['evidence_dir'])
        assert evidence.resolve().is_relative_to(public / 'verify-from-store')
        assert not list(evidence.glob('receipt-*'))
        shutil.copytree(evidence, path / 'evidence')
        assert not sentinel.exists(), 'public verifier created owner-private state'
        results.append({'category': category, 'publication_chunk': chunk['index'], 'accepted': True, 'guard': proof['guard'],
                        'output': str(path), 'stdout_sha256': sha(path / 'stdout.json'),
                        'owner_private_state_created': False})
    assert len(results) == 3
    return results


def cleanup_owned_scratch(private, public, output):
    assert private == PRIVATE and public == PUBLIC
    removed = []
    for path in (private, public):
        assert not path.is_symlink() and path.resolve() == path
        if path.exists():
            shutil.rmtree(path)
            removed.append(str(path))
    return {'removed_roots': removed, 'scratch_retained': False,
            'raw_receipts_replayable': False, 'model_source_files_changed': False,
            'public_verification_logs_retained': str(output)}
