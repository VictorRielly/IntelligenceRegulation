"""DEVELOPMENT CANDIDATE (lane A24, 2026-11-07; binary from lane A28): the resident-server Shieldstral prover.

Selected only by PM_PROVER=shieldstral-fast. It proves the same registered moderate
policies (D61) on the same T128 export and templates as the reviewed `shieldstral` mode,
but with a newer zk60_classify build (post-F12 R13 profile /2, its own model identity)
run as two long-lived native servers (`serve`, `check-serve`) on the Mac's GPU, with
several categories proved at once. D58 accepted ONLY the named r16b CPU binary: this
binary, its GPU execution and its server/concurrent form are NOT covered; its privacy
statement is pending. Nothing here is production (D63). No automatic binary or profile
upgrade: every pin below is checked before use.

Lane A26 (2026-11-07, results/zk60_a26_app_20261107/README.md) pins a newer build of the same
servers: the same receipts byte for byte (checked under fixed test entropy on the real export),
the same statement identity, profile and verifier verdicts, with less CPU work per proof (the
24-bit FFN down projection on the device as two exact int16 halves; the verifier's column test
over its weights' nonzero rows and the slots' public tables through split eq tables; the run's
CS-1 / CS-4 record kept for the core proof) and one Metal queue per prover thread.

Lane A27 (2026-11-07, results/zk60_a27_app_20261107/README.md) pins a newer build again: the same
receipts byte for byte (fixed test entropy on the real export, against A26's binary), the same
statement identity, profile and verdicts, with less GPU work per proof (the zero-checks' linear
parts kept as device tables, the round values above an IR's attained degree extrapolated, the
folds in three products, the commitment NTT two stages per pass).

Lane A28 (2026-11-09, results/zk60_a28_app_20261107/README.md) pins a newer build again: the same
receipts byte for byte (fixed test entropy on the real export, against A27's binary), the same
statement identity, profile and verdicts, with a little less GPU work per proof (the commitment's
forward transform skips the zero half of its first pass; the column hash in two passes). The
build's seal-ahead mode (HL_A28_SEAL_AHEAD) is off by default and the app does not set it. The
servers wait for the GPU by spinning 200 us and then blocking, and start requests 300 ms apart.
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
# below is the authority. Built from lane A28's tree with `--features gpu-metal` (A27's was
# `zk60_classify.a27`, b5b6b9a4...; A26's `zk60_classify.a26`, b6336628...; A24's
# `zk60_classify.a24`, ccd58102...; their receipts are the same bytes).
LANE = 'A28'
BINARY = Path(os.environ.get('PM_FAST_BINARY', str(config.HOME / 'zk60-artifacts/proven-media-fast/bin/zk60_classify.a28')))
BINARY_SHA = '80f2b70481fba51df6118b25a19e2d0c4c6e1ddb4e10b00c96e0ca2252935157'
PROFILE_SHA = reviewed.PROFILE_SHA
IDENTITY = 'e4f97455f9a301ea8646ae1754bb29de52e51798ae7e8e435a597eedbcf3279d'
RUN_PROFILE = 'hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/2'
CLI_DESCRIPTION = 'zk60_classify A28 serve/check-serve (A24 servers, A26 work cuts, A27 and A28 kernels), post-F12 R13 /2, T128, Metal'
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
# [A28] (results/zk60_a28_app_20261107/README.md) measured and left as they were: three writers
# at once with twelve jobs in flight made one short post 5% faster (its third category no longer
# waits for a writer slot) but one long post 5% slower and the 8-post stream no faster (the six
# lanes are loaded sooner and every proof then takes longer); more threads a lane, more lanes and
# two requests a lane did not pay either.
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
            'HL_PB_ORACLE': '0', 'HL_PB_TIMING': '0', **NATIVE_SETTINGS}


# [A26] the servers' device settings, measured on the M3 Ultra (results/zk60_a26_app_20261107):
# one Metal command queue per prover thread (A7's opt-in; the stream is GPU-bound and its lanes'
# command buffers then run side by side). Every A26 work cut is on by default in the binary; the
# two that wait for the security owner's reading stay off (HL_A26_KEPT, HL_A26_VERIFY_ONCE).
# [A27] every A27 kernel change is on by default in the binary (each has an HL_A27_*=0 switch the
# app does not set). None of these moves a byte.
# [A28] the two A28 commitment kernels are on by default in the binary (HL_A28_PRUNE, HL_A28_HASH;
# the app sets neither); its seal-ahead mode stays off (HL_A28_SEAL_AHEAD: +1.3% on the stream for
# about 60 GiB more memory, results/zk60_a28_app_20261107). Two settings measured there (A B C C B A
# against A27 on the stream, pairs on one post): A7's spin-then-block wait for a command buffer
# (HL_METAL_SPIN_US=200: the prover's CPU per proof -22%) and a 300 ms minimum between request
# starts (HL_A28_STAGGER_MS=300: a post's three categories no longer run in lockstep). With the
# A28 binary the native stream is +2.9% over A27 (+1.4% of it from these two settings, inside the
# runs' spread) and one post -3%; through the app the stream is the same with or without them.
# They change when a thread waits and when a request starts, never a byte (the byte-identity run
# covers the stagger).
NATIVE_SETTINGS = {'HL_METAL_QUEUES': 'thread', 'HL_METAL_SPIN_US': '200', 'HL_A28_STAGGER_MS': '300'}


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
            and deploy.min_bits == 95 and deploy.overlap == 8, f'deployment differs from the pinned {LANE} candidate')
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
