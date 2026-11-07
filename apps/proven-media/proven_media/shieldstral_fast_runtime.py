"""DEVELOPMENT CANDIDATE (lane A24, 2026-11-07): the resident-server Shieldstral prover.

Selected only by PM_PROVER=shieldstral-fast. It proves the same registered moderate
policies (D61) on the same T128 export and templates as the reviewed `shieldstral` mode,
but with a newer zk60_classify build (post-F12 R13 profile /2, its own model identity)
run as two long-lived native servers (`serve`, `check-serve`) on the Mac's GPU, with
several categories proved at once. D58 accepted ONLY the named r16b CPU binary: this
binary, its GPU execution and its server/concurrent form are NOT covered; its privacy
statement is pending. Nothing here is production (D63). No automatic binary or profile
upgrade: every pin below is checked before use.
"""
import os
from pathlib import Path

from . import config, records
from . import shieldstral_runtime as reviewed
from .classifier_cli import Deployment, R_C3_SCHEMA, require

KIND = 'shieldstral-fast'
# The export's large arrays (the 805 MB embedding, the layer weights) are untracked files of the
# main checkout; a worktree points at them with PM_FAST_EXPORT_ROOT. The profile digests below
# and the native verifier's own checks still decide.
EXPORT_ROOT = Path(os.environ.get('PM_FAST_EXPORT_ROOT', str(reviewed.EXPORT_ROOT)))
EXPORT = EXPORT_ROOT / reviewed.EXPORT.name
VERIFIER_EXPORT = EXPORT_ROOT / reviewed.VERIFIER_EXPORT.name
# The binary lives outside the repository (no binaries in the public repo, D62); the pin
# below is the authority. Built from lane A24's tree with `--features gpu-metal`.
BINARY = Path(os.environ.get('PM_FAST_BINARY', str(config.HOME / 'zk60-artifacts/proven-media-fast/bin/zk60_classify.a24')))
BINARY_SHA = 'ccd58102e3fdbe4fb0be3446b5d539cd6741779a6efaea073251ef040968a946'
PROFILE_SHA = reviewed.PROFILE_SHA
IDENTITY = 'e4f97455f9a301ea8646ae1754bb29de52e51798ae7e8e435a597eedbcf3279d'
RUN_PROFILE = 'hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/2'
CLI_DESCRIPTION = 'zk60_classify A24 serve/check-serve, post-F12 R13 /2, T128, Metal'
# Astra's Mac activation writer (qualified against the native writer, 2026-11-05). It and the
# public model root are untracked files of the main checkout (not in git): a worktree points
# at them with PM_FAST_WRITER_ROOT / PM_FAST_MODELS. The pins below still decide.
WRITER_ROOT = Path(os.environ.get('PM_FAST_WRITER_ROOT', str(config.REPO / 'results/zk60_astra_20261026/a3_mac_writer_20261105')))
WRITER = WRITER_ROOT / 'write_item_activations.py'
WRITER_SHA = '27a6742dbb3fdc8d47cd53406579379608b56cff6a2f8c334fdc54768d6388d5'
WRITER_DEPENDENCIES = {
    WRITER_ROOT / 'mac_model.py': 'c4cc0293481728c37de78ee6162f371ddba155a3f351eb56261c6ef18c61cb8f',
    WRITER_ROOT / 'source-pins.json': 'ae9e06504d1cc07686123290f25df940d3968cdeb28e40d450730c7d48a668ef',
}
NATIVE_MODELS = Path(os.environ.get('PM_FAST_MODELS', str(config.REPO / 'results/zk60_astra_20261026/flashprove_runtime_20261104/models')))
WRITER_PYTHON = os.environ.get('PM_FAST_WRITER_PYTHON', os.environ.get('PM_SYSTEM_PYTHON', config.SYSTEM_PYTHON))
TEKKEN = reviewed.TEKKEN

# Server settings measured on the M3 Ultra (results/zk60_a24_app_20261107/README.md): six
# prover lanes of five rayon threads (two posts' categories at once; native stream steady
# 12.7 proved tok/s against 10.1 with three lanes of ten), three verifier lanes of four, the
# sealing pass's witnesses kept up to 16 GiB per request. The app keeps up to JOBS_IN_FLIGHT
# category jobs at the service, so the prover lanes stay busy while others write or verify.
PROVER_LANES = 6
PROVER_LANE_THREADS = 5
WITNESS_CACHE_GIB = 16
CHECK_LANES = 3
CHECK_LANE_THREADS = 4
WRITER_THREADS = 4
WRITERS_AT_ONCE = 2
JOBS_IN_FLIGHT = PROVER_LANES + CHECK_LANES
# The whole service is one guarded gpu-class job for its life (both servers, the writers).
# Measured peak of the guarded tree: 102.5 GiB (six prover lanes, a stream); need/cap add margin.
SERVICE_NEED_GIB = 110
SERVICE_CAP_GIB = 180
SERVICE_MAX_SECONDS = 6 * 3600
SERVICE_IDLE_SECONDS = int(os.environ.get('PM_FAST_IDLE_SECS', '300'))
# A request's own limits inside the service (seconds); a slower step fails closed.
STEP_TIMEOUTS = {'seqgen': 600, 'prove': 900, 'check': 900}


def categories():
    return reviewed.categories()


def templates():
    return reviewed.templates()


def native_environment():
    """The public model root for the tied-table derivation and the device settings.

    Native verification still authenticates the checkpoint and the tied tables.
    """
    root = NATIVE_MODELS.resolve(strict=True)
    require((root / 'shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors').is_file(),
            'configured public model is unavailable')
    return {'ZK60_MODELS': str(root), 'HL_GPU': '1', 'HL_GPU_REQUIRED': '0',
            'HL_PB_ORACLE': '0', 'HL_PB_TIMING': '0'}


def privacy_statement():
    from .classifier_privacy import statement_info
    return statement_info(descriptor())


def descriptor():
    return {'kind': KIND, 'binary_sha256': BINARY_SHA, 'model_digest': IDENTITY,
            'token_profile_digest': PROFILE_SHA, 'run_profile': RUN_PROFILE, 'cli': CLI_DESCRIPTION,
            'device': 'metal', 'proof_mode': 'resident-server, categories proved concurrently',
            'policy_ids': [c['policy_id'] for c in categories()],
            'privacy_adapter_supported': False, 'batch_proving': False}


def deployment(template):
    return Deployment(BINARY, BINARY_SHA, EXPORT, VERIFIER_EXPORT, VERIFIER_EXPORT / 'token_io',
                      IDENTITY, template.policy_id, template.chunk_size, 8, 95, False, R_C3_SCHEMA)


def validate(deploy):
    require(not deploy.development and deploy.binary == BINARY and deploy.binary_sha256 == BINARY_SHA
            and deploy.statement_identity == IDENTITY and deploy.statement_schema == R_C3_SCHEMA
            and deploy.min_bits == 95 and deploy.overlap == 8, 'deployment differs from the pinned A24 candidate')
    by_policy = {t.policy_id: t for t in templates()}
    require(deploy.policy in by_policy and deploy.chunk_size == by_policy[deploy.policy].chunk_size,
            'real category or geometry changed')
    for directory in (deploy.prover_export, deploy.verifier_export):
        require(records.sha256_file(directory / 'profile.json') == PROFILE_SHA, 'real export profile changed')
    require(deploy.tables.resolve() == (deploy.verifier_export / 'token_io').resolve(), 'real tied tables differ')
    require(records.sha256_file(WRITER) == WRITER_SHA, 'activation writer differs from tested source')
    for path, expected in WRITER_DEPENDENCIES.items():
        require(records.sha256_file(path) == expected, 'activation writer dependency changed')
    deploy.validate()


def service_dir():
    return config.PRIVATE_DIR / 'fast-service'


def server_argv(kind):
    """The two native servers' command lines (public paths and settings only)."""
    policies = ','.join(c['policy_id'] for c in categories())
    tables = str(VERIFIER_EXPORT / 'token_io')
    if kind == 'prove':
        return [str(BINARY), 'serve', '--export', str(EXPORT), '--tables', tables, '--policies', policies,
                '--label', 'zk60-classify-verdict', '--lanes', str(PROVER_LANES),
                '--lane-threads', str(PROVER_LANE_THREADS), '--witness-cache-gib', str(WITNESS_CACHE_GIB)]
    require(kind == 'check', 'unknown native server')
    return [str(BINARY), 'check-serve', '--export', str(VERIFIER_EXPORT), '--tables', tables, '--policies', policies,
            '--label', 'zk60-classify-verdict', '--expect-statement', IDENTITY, '--min-bits', '95',
            '--lanes', str(CHECK_LANES), '--lane-threads', str(CHECK_LANE_THREADS)]
