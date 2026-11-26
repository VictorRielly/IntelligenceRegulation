"""Validate the operator's real-classifier profile against the native pins.

This does not retune or select the prover. The existing runtime is authoritative
for geometry and guard declarations; the JSON is a checked deployment record.
"""
import json
from pathlib import Path

from . import config, records, shieldstral_runtime as runtime
from .classifier_cli import require


def classifier_profile(path=None, name=None):
    path = Path(path or config.DEPLOY_FILE)
    settings = json.loads(path.read_text())
    name = name or settings.get('active_classifier_profile')
    profiles = settings.get('classifier_profiles', {})
    require(name in profiles, 'unknown real classifier hardware profile')
    profile = profiles[name]
    templates = runtime.templates()
    geometry = {t.category: {'chunk_tokens': t.chunk_size, 'overlap_tokens': t.overlap, 'max_chunks': t.max_chunks}
                for t in templates}
    resources = {step: dict(zip(('need_gib', 'cap_gib', 'max_seconds'), values))
                 for step, values in runtime.RESOURCES.items()}
    expected = {'prover_mode': 'shieldstral', 'device': 'cpu', 'cpu_threads': 2, 'context_tokens': 128,
                'max_content_tokens': min(t.chunk_size + (t.max_chunks - 1) * (t.chunk_size - t.overlap) for t in templates),
                'category_geometry': geometry, 'guard_resources': resources, 'binary_sha256': runtime.BINARY_SHA,
                'statement_identity': runtime.IDENTITY, 'profile_sha256': runtime.PROFILE_SHA, 'min_bits': 95,
                'privacy_status': runtime.privacy_statement()['status']}
    require(type(profile) is dict and all(records.canonical(profile.get(k)) == records.canonical(v) for k, v in expected.items()),
            'hardware profile differs from the reviewed runtime; geometry and safety floors cannot be retuned here')
    return {'name': name, **profile, 'validated_against_runtime': True, 'file': str(path)}


FAST_PROFILE = 'shieldstral-mac-fast'
RESIDENT_FAST_PROFILE = 'shieldstral-mac-fast-resident-writer'
W16_FAST_PROFILE = 'shieldstral-mac-fast-w16r2'


def fast_classifier_profile(path=None, name=None, *, runtime_module=None):
    """[A24] The Mac's resident-server profile (PM_PROVER=shieldstral-fast, development
    candidate), validated against shieldstral_fast_runtime the same way: the JSON records the
    measured settings; it cannot retune geometry, pins, floors or resource declarations."""
    from .fast_runtime_selection import runtime_for
    fast = runtime_module if runtime_module is not None else runtime_for('shieldstral-fast-w16r2' if config.prover_mode() == 'shieldstral-fast-w16r2' else 'shieldstral-fast')
    w16 = fast.KIND == 'shieldstral-fast-w16r2'
    name = name or (W16_FAST_PROFILE if w16 else RESIDENT_FAST_PROFILE if fast.writer_mode() == 'resident' else FAST_PROFILE)
    path = Path(path or config.DEPLOY_FILE)
    settings = json.loads(path.read_text())
    profiles = settings.get('classifier_profiles', {})
    require(name in profiles, 'unknown real classifier hardware profile')
    profile = profiles[name]
    templates = fast.templates()
    geometry = {t.category: {'chunk_tokens': t.chunk_size, 'overlap_tokens': t.overlap, 'max_chunks': t.max_chunks}
                for t in templates}
    expected = {'prover_mode': fast.KIND, 'device': 'metal', 'context_tokens': 128,
                'max_content_tokens': min(t.chunk_size + (t.max_chunks - 1) * (t.chunk_size - t.overlap) for t in templates),
                'category_geometry': geometry, 'binary_sha256': fast.BINARY_SHA, 'statement_identity': fast.IDENTITY,
                'profile_sha256': fast.PROFILE_SHA, 'min_bits': 95,
                'servers': {'prover_lanes': fast.PROVER_LANES, 'prover_lane_threads': fast.PROVER_LANE_THREADS,
                            'witness_cache_gib': fast.WITNESS_CACHE_GIB, 'check_lanes': fast.CHECK_LANES,
                            'check_lane_threads': fast.CHECK_LANE_THREADS, 'writer_threads': fast.WRITER_THREADS,
                            'writers_at_once': fast.WRITERS_AT_ONCE},
                'guard_resources': {'service': fast.service_resources()},
                'native_settings': fast.NATIVE_SETTINGS,
                'privacy_status': fast.privacy_statement()['status'], 'production': False}
    if w16:
        expected.update(public_content_only=True, prover_binary_sha256=fast.PROVER_BINARY_SHA,
                        native_cli_flags=['--dev-w16r2-public-content-only'],
                        native_intake_sha256=fast.intake_sha, activation_writer='resident')
    require(type(profile) is dict and all(records.canonical(profile.get(k)) == records.canonical(v) for k, v in expected.items()),
            f'hardware profile differs from the {fast.LANE} runtime; geometry and safety floors cannot be retuned here')
    return {'name': name, **profile, 'validated_against_runtime': True, 'file': str(path)}


if __name__ == '__main__':
    print(json.dumps(fast_classifier_profile() if config.prover_mode() in ('shieldstral-fast', 'shieldstral-fast-w16r2') else classifier_profile(), indent=2))
